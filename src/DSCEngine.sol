// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "src/libraries/OracleLib.sol";

/**
 * @title DSCEngine
 * This system is designed for maximum simplicity in view of having tokens maintain a 1 token == 1 USD value.
 * The properties of the system are as follows:
 * 1. Relative Stability: The system is pegged to the USD.
 * 2. Stability Mechanism: The system is designed to be decentralized i.e. algorithmic minting and burning of tokens
 * The system is currently similar to DAI but with a few differences:
 * 1. No Governance Token: The system does not have a governance token.
 * 2. No Stability Fee: The system does not have a stability fee.
 * 3. The system backed by WETH and WBTC with placeholders for other tokens (e.g. Gold, Silver, etc.)
 *
 * The system should always be over-collateralized to ensure the stability of the system.
 * At no point should the value of the collateral be less than the dollar backed value of the DSC tokens minted.
 * The system is losely based on the MakerDAO DSS DAI system.
 * @notice DSCEngine is the engine the core of the DSC system handling all the logic for minting (mining) and burning (redeeming) of DSC tokens.  It also handles the logic of depositing and withdrawing collateral.
 * @notice The DSCEngine functions have some commented input variables that are not used in the function. These are placeholders for future functionality.
 */

contract DSCEngine is ReentrancyGuard {
    ////////////////////////
    //////Errors///////////
    ////////////////////////
    error DSCEngine__AmountMustBeGreaterThanZero();
    error DSCEngine_TokenAddressesLengthDoesNotMatchPriceFeedAddressesLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__CollateralTransferFailed();
    error DSCEngine__BrokeHealthFactor();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorIsAboveThreshold();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__RedeemAmountExceedsDepositedCollateral();

    ////////////////////////
    ///Type Declarations////
    ////////////////////////

    using OracleLib for AggregatorV3Interface;

    ////////////////////////
    ///State Variables//////
    ////////////////////////

    mapping(address token => address priceFeed) private s_priceFeeds; // Mapping of token address to price feed address. Initialized in the constructor
    mapping(address user => mapping(address token => uint256 amount))
        private s_userColDeposited; // Mapping of user address to mapping of token address to amount of collateral deposited. Initialized in the depositCollateral function
    mapping(address user => uint256 amountDscMinted) private s_userDscMinted; // Mapping of user address to amount of DSC minted. Initialized in the mintDSC function
    DecentralizedStableCoin private immutable i_dsc; // Instance of the DecentralizedStableCoin contract. Initialized in the constructor
    address[] private s_collateralTokens; // Array of collateral tokens. Initialized in the constructor
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; // Precision for price feed calculations. Multiply by the price feed value which is in 8 decimals
    uint256 private constant PRECISION = 1e18; // Used in pricefeed and other price division calculations
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // Reresenting 50%. The user needs to be 200% collateralized to avoid liquidation. This is a 50% threshold meaning DSC minted should be less than 50% of the collateral value in USD
    uint256 private constant LIQUIDATION_PRECISION = 100; // Precision for liquidation calculations. Divide the LIQUIDATION_THRESHOLD by this value to get the liquidation threshold
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // The minimum health factor for a user to avoid liquidation
    uint256 private constant LIQUIDATION_BONUS = 10; // The bonus for the liquidator. The liquidator gets 10% of the value of the debt to cover as a bonus. Divide by the LIQUIDATION_PRECISION to get the bonus

    ////////////////////////
    ////////Events//////////
    ////////////////////////

    // Event emitted when a user deposits collateral
    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );
    // Event emitted when a user withdraws collateral
    event CollateralRedeemed(
        address indexed redeemedFrom,
        address indexed redeemedTo,
        address indexed token,
        uint256 amount
    );
    ////////////////////////
    //////Modifiers////////
    ////////////////////////

    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert DSCEngine__AmountMustBeGreaterThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    ////////////////////////
    //////Functions////////
    ////////////////////////
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address _dscAddress // uint256[] memory liquidationThresholds
    ) {
        // USD Price Feeds
        // if (tokenAddresses.length != priceFeedAddresses.length || tokenAddresses.length != liquidationThresholds.length)
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine_TokenAddressesLengthDoesNotMatchPriceFeedAddressesLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            // Initialize the s_priceFeeds mapping
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i]; // mapping(address token => address priceFeed) private s_priceFeeds;
            // Update the s_collateralTokens array
            s_collateralTokens.push(tokenAddresses[i]); // array of collateral tokens
            // Initialize the tokenLiquidationThresholds mapping
            // tokenLiquidationThresholds[tokenAddresses[i]] = liquidationThresholds[i]; // mapping(address => uint256) private tokenLiquidationThresholds;
        }
        i_dsc = DecentralizedStableCoin(_dscAddress); // Instance of the DecentralizedStableCoin contract
    }

    ///////////////////////////////////////////////////////
    /////////* External & Public Functions *////////////////
    ///////////////////////////////////////////////////////

    /*
     * @notice: function depositCollateralAndMintDSC()
     * @notice: This is a convenience function that allows the user to deposit collateral and mint DSC in one transaction.
     * @param tokenCollateralAddress: The address of the token to be deposited as collateral
     * @param amountCollateral: The amount of the token to be deposited as collateral
     * @param amountDscToMint: The amount of DSC to mint
     */
    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint /*,tokenCollateralAddress*/);
    }

    /*
     * @notice: function depositCollateral()
     * @notice: Follows CEI: Checks-Effects-Interactions pattern
     * @param tokenCollateralAddress: The address of the token to be deposited as collateral
     * @param amountCollateral: The amount of the token to be deposited as collateral
     * Checks: Check if the amount of collateral is greater than 0
     * Checks: Check if the token is allowed as collateral with regards to the s_priceFeeds mapping.
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        moreThanZero(amountCollateral) // check
        isAllowedToken(tokenCollateralAddress) // check
        nonReentrant
    {
        // Effects: Update state before interacting with external contracts
        s_userColDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );

        // Interactions: Transfer the collateral from the user to the DSCEngine contract
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__CollateralTransferFailed();
        }
    }

    /*
     * @notice: function mintDSC()
     * @notice follows CEI: Checks-Effects-Interactions pattern
     * @param amountDscToMint The amount of DSC to mint
     * @notice the user must have more collateral value than the minimum threshold for DSC to be minted
     */
    function mintDSC(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) nonReentrant {
        // Effects: Update the state of the s_userDscMinted mapping
        s_userDscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBelowThreshold(msg.sender);

        // Interactions: Mint the DSC
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    /*
     * @notice: function redeemCollateralForDSC()
     * @notice: This is a convenience function that allows the user to burn DSC and redeem collateral in one transaction.
     * @param tokenCollateralAddress: The address of the token to be redeemed
     * @param amountCollateral: The amount of the token to be redeemed
     * @param amountDscToBurn: The amount of DSC to burn
     */
    function redeemCollateralForDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    ) external {
        burnDSC(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    /*
     * @notice: function redeemCollateral()
     * @notice: Allows the user to redeem collateral
     * @notice: Follows CEI: Checks-Effects-Interactions pattern
     * @notice: The user must have a health factor greater than 1 AFTER redeeming the collateral to avoid liquidation. This may violate the CEI pattern.
     * @param tokenCollateralAddress: The address of the token to be redeemed
     * @param amountCollateral: The amount of the token to be redeemed
     */
    function redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) public moreThanZero(amountCollateral) nonReentrant {
        // Effects: Update the state before interacting with external contracts
        _redeemCollateral(
            msg.sender,
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
        _revertIfHealthFactorIsBelowThreshold(msg.sender);
    }

    /*
     * @notice: function burnDSC()
     * @notice: Allows the user to burn DSC
     * @param amount: The amount of DSC to burn
     */
    function burnDSC(uint256 amount) public moreThanZero(amount) {
        // Effects: Update the state before interacting with external contracts
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBelowThreshold(msg.sender);
    }

    /*
     * @notice: function liquidate()
     * @notice: Allows the system to liquidate a user if the health factor is below the MIN_HEALTH_FACTOR
     * @param tokenCollateralAddress: The address of the token to be redeemed
     * @param user: The address of the user
     * @param debtToCover: The amount of DSC to burn to cover the debt and improve the user's health factor
     * @notice: The user can be partially liquidated with a liquidation bonus for the liquidator
     * @notice: The bonus is the difference between the collateral value in USD and the debt to cover
     * @notice: The liquidation process only kicks if the health factor is below the MIN_HEALTH_FACTOR
     * @notice: The incentive only works if the protocol is over-collateralized
     * @notice: follows CEI: Checks-Effects-Interactions pattern
     */
    function liquidate(
        address tokenCollateralAddress,
        address user,
        uint256 debtToCover
    ) external moreThanZero(debtToCover) nonReentrant {
        // Checks: Verify that the user's health factor is below the threshold
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsAboveThreshold();
        }

        // Effects: Calculate required collateral and bonuses
        uint256 collateralAmountToCoverDebt = getCollateralAmountFromUSDValue(
            tokenCollateralAddress,
            debtToCover
        );

        uint256 liquidationBonus = (collateralAmountToCoverDebt *
            LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = collateralAmountToCoverDebt +
            liquidationBonus;

        // Interactions: Redeem collateral and burn DSC
        _redeemCollateral(
            user,
            msg.sender,
            tokenCollateralAddress,
            totalCollateralToRedeem
        );
        _burnDsc(debtToCover, user, msg.sender);

        // Checks: Verify that the user's health factor has improved
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorNotImproved();
        }

        // Checks: Verify that the liquidator's health factor is above the threshold
        _revertIfHealthFactorIsBelowThreshold(msg.sender);
    }

    /////////////////////////////////////////////////////////////////////
    ////////////////* Internal & Private View Functions *////////////////
    /////////////////////////////////////////////////////////////////////

    /*
     * @dev: function _burnDsc()
     * @dev: This is a low-level internal function to be called only if the calling function checks for the health factor
     * @param amountDscToBurn
     * @param onBehalfOf is the address of the user whose DSC is being burned and who is receiving the collateral
     * @param dscFrom is the user's address from which the DSC is being burned
     */
    function _burnDsc(
        uint256 amountDscToBurn,
        address onBehalfOf,
        address dscFrom
    ) private {
        // Effects: Update the state of the s_userDscMinted mapping
        s_userDscMinted[onBehalfOf] -= amountDscToBurn;

        // Interactions: Transfer DSC from the user and burn it
        bool success = i_dsc.transferFrom(
            dscFrom,
            address(this),
            amountDscToBurn
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    /*
     * @dev:function _redeemCollateral()
     * @notice: An internal function that enables both liquidation and normal redemption of collateral
     * @param from: The address of the caller
     * @param to: The address of the recipient
     * @param tokenCollateralAddress
     * @param amountCollateral
     */
    // function _redeemCollateral(
    //     address from,
    //     address to,
    //     address tokenCollateralAddress,
    //     uint256 amountCollateral
    // ) private {
    //     // Effects: Update the state of the s_userColDeposited mapping
    //     s_userColDeposited[from][tokenCollateralAddress] -= amountCollateral;
    //     emit CollateralRedeemed(
    //         from,
    //         to,
    //         tokenCollateralAddress,
    //         amountCollateral
    //     );

    //     // Interactions: Transfer the collateral to the caller
    //     bool success = IERC20(tokenCollateralAddress).transfer(
    //         to,
    //         amountCollateral
    //     );
    //     if (!success) {
    //         revert DSCEngine__CollateralTransferFailed();
    //     }
    // }
    function _redeemCollateral(
        address from,
        address to,
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) private {
        uint256 depositedCollateral = s_userColDeposited[from][
            tokenCollateralAddress
        ];

        // Check if the amount to redeem is greater than the deposited collateral
        if (amountCollateral > depositedCollateral) {
            revert DSCEngine__RedeemAmountExceedsDepositedCollateral();
        }

        // Effects: Update the state of the s_userColDeposited mapping
        s_userColDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(
            from,
            to,
            tokenCollateralAddress,
            amountCollateral
        );

        // Interactions: Transfer the collateral to the caller
        bool success = IERC20(tokenCollateralAddress).transfer(
            to,
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__CollateralTransferFailed();
        }
    }

    /*
     * @notice: function _getAccountInformation()
     * @notice: Returns the total DSC minted by the user and the collateral value in USD
     * @param _user: The address of the user
     */
    function _getAccountInformation(
        address _user
    )
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValInUsd)
    {
        // Get the total DSC minted by the user
        totalDscMinted = s_userDscMinted[_user];
        // Get the collateral value in USD
        collateralValInUsd = getAccountCollateralValueInUsd(_user);
        return (totalDscMinted, collateralValInUsd);
    }

    /*
     * @notice: function _healthFactor()
     * @notice: Returns how close the user is to being liquidated
     * @param user: The address of the user
     */
    function _healthFactor(address user) private view returns (uint256) {
        // Retrieve the user account details (Collateral value in USD derived from the getAccountCollateralValueInUsd function and the total DSC minted by the user)
        (
            uint256 totalDscMinted,
            uint256 collateralValInUsd
        ) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValInUsd);
    }

    function _calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValInUsd
    ) internal pure returns (uint256) {
        if (totalDscMinted <= 0) {
            return type(uint256).max;
        }

        uint256 collateralAdjustedForThreshold = (collateralValInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    // check health factor and revert if they dont meet the threshold
    function _revertIfHealthFactorIsBelowThreshold(address user) private view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BrokeHealthFactor();
        }
    }

    /////////////////////////////////////////////////////////////////////
    ////////////////* Public & External View Functions */////////////////
    /////////////////////////////////////////////////////////////////////

    /*
     * @notice: function getCollateralAmountFromUSDValue()
     * @notice: Returns the amount of collateral in USD required to cover the debt in USD.
     * @param tokenCollateralAddress: The address of the token to be deposited as collateral
     * @param usdValueInWei: The value of the collateral in USD
     */
    function getCollateralAmountFromUSDValue(
        address tokenCollateralAddress,
        uint256 usdValueInWei
    ) public view returns (uint256) {
        // Get the price of ETH in USD from the price feed
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[tokenCollateralAddress]
        );
        (, int256 price, , , ) = priceFeed.stalePriceCheckLatestRoundData();
        // Calculate the amount of collateral required to cover the debt in USD
        return ((usdValueInWei * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    /*
     * @notice: function getAccountCollateralValueInUsd()
     * @param user: The address of the user
     */
    function getAccountCollateralValueInUsd(
        address user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        // Loop through the s_collateralTokens array to get the total collateral value in USD
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_userColDeposited[user][token];
            totalCollateralValueInUsd += getUsdValueOfCollateral(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    /*
     * @notice: function getUsdValueOfCollateral()
     * @param token: The address of the token
     * @param amount: The amount of the token
     */
    function getUsdValueOfCollateral(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.stalePriceCheckLatestRoundData();
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValInUsd
    ) external pure returns (uint256) {
        return _calculateHealthFactor(totalDscMinted, collateralValInUsd);
    }

    function getAccountInformation(
        address user
    )
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValInUsd)
    {
        (totalDscMinted, collateralValInUsd) = _getAccountInformation(user);
        return (totalDscMinted, collateralValInUsd);
    }

    function getDepositedCollateralAmount(
        address user,
        address token
    ) external view returns (uint256) {
        return s_userColDeposited[user][token];
    }

    function getDscMintedAmount(address user) external view returns (uint256) {
        return s_userDscMinted[user];
    }

    function getPrecision() external pure returns (uint256) {
        return (PRECISION);
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return (ADDITIONAL_FEED_PRECISION);
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return (LIQUIDATION_PRECISION);
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return (LIQUIDATION_BONUS);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getDscContract() external view returns (address) {
        return address(i_dsc);
    }
}
