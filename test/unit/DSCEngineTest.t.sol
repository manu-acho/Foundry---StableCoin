// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {MockFailedTransfer} from "test/mocks/MockFailedTransfer.sol";
import {MockMoreDebtDSC} from "test/mocks/MockMoreDebtDSC.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address public USER = makeAddr("user");
    uint256 public constant COLLATERAL_AMOUNT = 10e18; // 2000e8 * 1e10 * 10e18 / 1e18 = 20000e18 (USD)
    uint256 public constant STARTING_ERC20_BALANCE = 100e18;
    uint256 public constant DSC_AMOUNT = 100e18;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    // variables for liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    event CollateralRedeemed(
        address indexed redeemedFrom,
        address indexed redeemedTo,
        address indexed token,
        uint256 amount
    );

    modifier depositedCollateral() {
        vm.startPrank(USER);
        // Approve the collateral token to the DSCEngine contract
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        // Deposit the collateral token to the DSCEngine contract
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintedDSC() {
        vm.startPrank(USER);
        // Approve the collateral token to the DSCEngine contract
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        // Deposit the collateral token to the DSCEngine contract
        dscEngine.depositCollateralAndMintDSC(
            weth,
            COLLATERAL_AMOUNT,
            DSC_AMOUNT
        );
        vm.stopPrank();
        _;
    }

    modifier liquidated() {
        // Arrange - set up the test
        vm.startPrank(USER);
        // Approve the collateral token to the DSCEngine contract
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        // Deposit the collateral token to the DSCEngine contract
        dscEngine.depositCollateralAndMintDSC(
            weth,
            COLLATERAL_AMOUNT,
            DSC_AMOUNT
        );
        vm.stopPrank();
        // Prepare the liquidation
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        // Rememeber, we need at least twice the collateral to cover the debt i.e $200 to cover $100 debt
        // Act: Update the price feed to crash the price
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        // get the user's health factor
        uint256 userHealthFactor = dscEngine.getHealthFactor(USER);
        // Mint eth to the liquidator
        ERC20Mock(weth).mint(liquidator, collateralToCover);
        vm.startPrank(liquidator);
        // Approve the collateral token to the DSCEngine contract
        ERC20Mock(weth).approve(address(dscEngine), collateralToCover);
        // Deposit the collateral token to the DSCEngine contract and Mint DSC
        dscEngine.depositCollateralAndMintDSC(
            weth,
            collateralToCover,
            DSC_AMOUNT
        );
        // Approve the DSC token to the DSCEngine contract
        dsc.approve(address(dscEngine), DSC_AMOUNT); // The DSC amount represents the debt to cover that the liquidator is willing to cover (burn) in order to redeem the collateral provided by the user
        // liquidate the user
        dscEngine.liquidate(weth, USER, DSC_AMOUNT);
        vm.stopPrank();

        _;
    }

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
         (ethUsdPriceFeed, btcUsdPriceFeed, , weth, , , ) = config
            .activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ////////////////////////////
    ///////Constructor Tests////
    ///////////////////////////

    function testConstructorRevertsIfTokenAddsLenghtDoNotMatch() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(
            DSCEngine
                .DSCEngine_TokenAddressesLengthDoesNotMatchPriceFeedAddressesLength
                .selector
        );
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////////////
    ///////Price Tests///////
    //////////////////////////

    function testgetUsdValueOfCollateral() public view {
        // We need three variables to test the getUsdValueOfCollateral function: An amount of collateral, the expected value of that collateral in USD, and the actual value of that collateral in USD. We then compare the expected value to the actual value with the assertEq function.
        uint256 ethAmount = 15e18;
        uint256 expectedUsdValue = 30000e18; // (2000e8 * 1e10 * 15e18 / 1e18 = 30000e18) ==> (uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
        uint256 actualUsdValue = dscEngine.getUsdValueOfCollateral(
            weth,
            ethAmount
        );
        assertEq(actualUsdValue, expectedUsdValue);
    }

    function getCollateralAmountFromUSDValue() public view {
        uint256 usdAmount = 100;
        uint256 expectedWeth = 0.05 ether; // (100e18 / 2000e8) / 1e10 = 0.05e18
        uint256 actualWeth = dscEngine.getCollateralAmountFromUSDValue(
            weth,
            usdAmount
        );
        assertEq(actualWeth, expectedWeth);
    }

    /////////////////////////////////////
    //depositCollateralAndMintDscTests //
    /////////////////////////////////////

    // Test that the user can deposit collateral to the DSCEngine contract
    function testDepositCollateral() public {
        vm.startPrank(USER);
        // Approve the collateral token to the DSCEngine contract
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        // Deposit the collateral token to the DSCEngine contract
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();

        // Check the balance of the DSCEngine contract to ensure that the collateral was deposited successfully
        uint256 contractBalance = ERC20Mock(weth).balanceOf(address(dscEngine));
        assertEq(
            contractBalance,
            COLLATERAL_AMOUNT,
            "Contract balance should match the deposited amount"
        );

        // Check the user's deposited balance in the DSCEngine contract
        uint256 userDepositedBalance = dscEngine.getDepositedCollateralAmount(
            USER,
            weth
        );
        assertEq(
            userDepositedBalance,
            COLLATERAL_AMOUNT,
            "User's deposited balance should match the deposited amount"
        );
    }

    // Test that the depositCollateral function reverts if the user has not deposited any collateral
    function testRevertsIfNoCollateralIsDeposited() public {
        vm.startPrank(USER);
        // We first need to approve the collateral token to the DSCEngine contract. This is necessary because the depositCollateral function transfers the collateral token from the user to the DSCEngine contract.
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        //We then call the depositCollateral function with the user's address and the amount of collateral to deposit.
        // We expect the function to revert because the user has not deposited any collateral.
        vm.expectRevert(
            DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector
        );
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    // Test that the depositCollateral function reverts if the user deposits an unapproved collateral token
    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock testToken = new ERC20Mock();
        testToken.mint(USER, COLLATERAL_AMOUNT);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dscEngine.depositCollateral(address(testToken), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    // Test that the user's account information can be retrieved from the DSCEngine contract
    function testGetAccountInformation() public depositedCollateral {
        uint256 totalDscMinted;
        uint256 collateralValInUsd;
        // Check the user's deposited balance in the DSCEngine contract
        console.log(
            "Amount of Collateral Deposited:",
            dscEngine.getDepositedCollateralAmount(USER, weth)
        );
        // Check the USD value of the collateral deposited by the user
        console.log(
            "Collateral Value in USD:",
            dscEngine.getUsdValueOfCollateral(weth, COLLATERAL_AMOUNT)
        );
        // Check the user's account information from the DSCEngine contract
        (totalDscMinted, collateralValInUsd) = dscEngine.getAccountInformation(
            USER
        );

        // Expected values based on the test setup
        uint256 expectedUsdValue = dscEngine.getUsdValueOfCollateral(
            weth,
            COLLATERAL_AMOUNT
        );
        console.log(
            "Expected Collateral Value in USD based on direct calculation:",
            expectedUsdValue
        );

        assertEq(
            collateralValInUsd,
            expectedUsdValue,
            "Collateral value in USD should match expected calculation"
        );
        assertEq(
            totalDscMinted,
            0,
            "No DSC should have been minted at this point"
        );
    }

    // Test that the user can deposit collateral and retrieve their account information
    // This test combines the depositCollateral and getAccountInformation tests
    // In addition, it checks the deposited amount of collateral against the expected value by calling the getCollateralAmountFromUSDValue function
    function testCanDepositCollateralAndGetAccountInfo()
        public
        depositedCollateral
    {
        // Check the balance of the DSCEngine contract to ensure that the collateral was deposited successfully
        console.log(
            "ERC20Mock WETH balance on DSCEngine:",
            ERC20Mock(weth).balanceOf(address(dscEngine))
        );
        // Check the user's deposited balance in the DSCEngine contract
        console.log(
            "Deposited Collateral on DSCEngine for USER:",
            dscEngine.getDepositedCollateralAmount(USER, weth)
        );
        // Retrieve the user's account information from the DSCEngine contract
        (uint256 totalDscMinted, uint256 collateralValInUsd) = dscEngine
            .getAccountInformation(USER);

        console.log("totalDscMinted: ", totalDscMinted);
        console.log("collateralValInUsd: ", collateralValInUsd);
        // Declare the expected values based on the test setup
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dscEngine
            .getCollateralAmountFromUSDValue(weth, collateralValInUsd);
        console.log("expectedDepositAmount: ", expectedDepositAmount);
        // Test: Compare the expected values to the actual values
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(COLLATERAL_AMOUNT, expectedDepositAmount);
    }

    function testCanDepositAndMintDSC() public depositedCollateralAndMintedDSC {
        // check the balance of the DSCEngine contract to ensure that the collateral was deposited successfully
        console.log(
            "ERC20Mock WETH balance on DSCEngine: ",
            ERC20Mock(weth).balanceOf(address(dscEngine))
        );
        // check the user's deposited balance in the DSCEngine contract
        console.log(
            "Deposited Collateral on DSCEngine for USER: ",
            dscEngine.getDepositedCollateralAmount(USER, weth)
        );
        // check the user's DSC balance in the DSC contract
        console.log("DSC balance for USER: ", dsc.balanceOf(USER));
        // Create the expected values based on the test setup
        uint256 expectedTotalDscMinted = DSC_AMOUNT;
        uint256 userDscBalance = dsc.balanceOf(USER);
        // Test: Compare the expected values to the actual values
        assertEq(userDscBalance, expectedTotalDscMinted);
    }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(
            DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector
        );
        dscEngine.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, 0);
        vm.stopPrank();
    }

    function testRevertsIfMintedDscBreaksHealthFactor() public {
        // Retrieve the latest price from the price feed
        (, int256 price, , , ) = MockV3Aggregator(ethUsdPriceFeed)
            .latestRoundData();
        uint256 amountCollateral = COLLATERAL_AMOUNT;
        // Set amountToMint to break the health factor
        uint256 amountToMint = (COLLATERAL_AMOUNT *
            (uint256(price) * dscEngine.getAdditionalFeedPrecision())) /
            dscEngine.getPrecision();
        // Begin interaction under USER account
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), amountCollateral);

        uint256 expectedHealthFactor = dscEngine.calculateHealthFactor(
            amountToMint,
            dscEngine.getUsdValueOfCollateral(weth, amountCollateral)
        );
        console.log("Expected Health Factor: ", expectedHealthFactor);
        // vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BrokeHealthFactor.selector, expectedHealthFactor));
        vm.expectRevert(DSCEngine.DSCEngine__BrokeHealthFactor.selector);
        dscEngine.depositCollateralAndMintDSC(
            weth,
            amountCollateral,
            amountToMint
        );
        vm.stopPrank();
    }

    ////////////////////////////////////////
    ///////burnDSCTests////////////////////
    ///////////////////////////////////////

    // Test that the burnDSC function reverts if the burn amount is zero
    function testRevertsIfBurnAmountIsZero()
        public
        depositedCollateralAndMintedDSC
    {
        vm.startPrank(USER);
        vm.expectRevert(
            DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector
        );
        dscEngine.burnDSC(0);
        vm.stopPrank();
    }

    // Test that the user can't burn more DSC than they have

    function testCantBurnMoreDSCThanUserHas() public {
        vm.startPrank(USER);
        vm.expectRevert();
        dscEngine.burnDSC(DSC_AMOUNT + 1);
    }

    // Test that the user can burn DSC and retrieve their account information

    function testUserCanBurnDscAndGetAccountInfo()
        public
        depositedCollateralAndMintedDSC
    {
        // Print the user's DSC balance before burning
        console.log("Attempting to burn DSC: ", DSC_AMOUNT);
        console.log("User's DSC balance before burn: ", dsc.balanceOf(USER));
        vm.startPrank(USER);
        // Approve the DSC token to the DSCEngine contract
        dsc.approve(address(dscEngine), DSC_AMOUNT);
        // Burn the DSC token
        dscEngine.burnDSC(DSC_AMOUNT);
        vm.stopPrank();
        // Check the user's DSC balance in the DSC contract
        console.log("DSC balance for USER: ", dsc.balanceOf(USER));
        // Retrieve the user's account information from the DSCEngine contract
        (uint256 totalDscMinted, uint256 collateralValInUsd) = dscEngine
            .getAccountInformation(USER);
        // Declare the expected values based on the test setup
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dscEngine
            .getCollateralAmountFromUSDValue(weth, collateralValInUsd);
        // Test: Compare the expected values to the actual values
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(COLLATERAL_AMOUNT, expectedDepositAmount);
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDSC {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), DSC_AMOUNT);
        dscEngine.burnDSC(DSC_AMOUNT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    //// redeemCollateral Tests ///////
    //////////////////////////////////

    function testRevertsIfTranferFails() public {
        // Arrange - set up the test
        address owner = msg.sender;
        vm.prank(owner);
        // Create a new instance of the MockFailedTransfer contract
        MockFailedTransfer mockDsc = new MockFailedTransfer();
        // define constructor arguments
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [ethUsdPriceFeed];
        // Create a new instance of the DSCEngine contract
        vm.prank(owner);
        DSCEngine mockDscEngine = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockDsc)
        );
        // mint DSC to the user
        mockDsc.mint(USER, COLLATERAL_AMOUNT);

        // transfer ownership of the mockDsc contract to the mockDscEngine contract
        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDscEngine));

        // Approve the DSC token to the DSCEngine contract
        vm.startPrank(USER);
        ERC20Mock(address(mockDsc)).approve(
            address(mockDscEngine),
            COLLATERAL_AMOUNT
        );
        // Deposit Collateral
        mockDscEngine.depositCollateral(address(mockDsc), COLLATERAL_AMOUNT);
        // Set up the test
        vm.expectRevert(DSCEngine.DSCEngine__CollateralTransferFailed.selector);
        mockDscEngine.redeemCollateral(address(mockDsc), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateralAndMintDSC(
            weth,
            COLLATERAL_AMOUNT,
            DSC_AMOUNT
        );
        vm.expectRevert(
            DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector
        );
        dscEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollateralAndMintedDSC {
        vm.startPrank(USER);
        // get the  user's wei balance before redeeming
        console.log(
            "User's WETH balance before redeeming: ",
            ERC20Mock(weth).balanceOf(USER)
        );
        // get the user's DSC balance
        console.log("User's DSC balance before burning: ", dsc.balanceOf(USER));
        dsc.approve(address(dscEngine), DSC_AMOUNT);
        dscEngine.burnDSC(DSC_AMOUNT);
        // get the user's DSC balance after burning
        console.log("User's DSC balance after burning: ", dsc.balanceOf(USER));
        dscEngine.redeemCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        uint256 userBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(userBalance, STARTING_ERC20_BALANCE);
    }

    function testEmitCollateralRedeemedWithCorrectArgs()
        public
        depositedCollateral
    {
        vm.expectEmit(true, true, true, true, address(dscEngine));
        emit CollateralRedeemed(USER, USER, weth, COLLATERAL_AMOUNT);
        vm.startPrank(USER);
        dscEngine.redeemCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    ///////////////////////////////////
    // redeemCollateralForDsc Tests //
    //////////////////////////////////

    function testMustRedeemMoreThanZero()
        public
        depositedCollateralAndMintedDSC
    {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), DSC_AMOUNT);
        vm.expectRevert(
            DSCEngine.DSCEngine__AmountMustBeGreaterThanZero.selector
        ); //
        dscEngine.redeemCollateralForDSC(weth, 0, DSC_AMOUNT);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateralAndMintDSC(
            weth,
            COLLATERAL_AMOUNT,
            DSC_AMOUNT
        );
        dsc.approve(address(dscEngine), DSC_AMOUNT);
        dscEngine.redeemCollateralForDSC(weth, COLLATERAL_AMOUNT, DSC_AMOUNT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    ////////////////////////
    // healthFactor Tests //
    ////////////////////////

    function testCorrectlyReportsHealthFactor()
        public
        depositedCollateralAndMintedDSC
    {
        // Collateral Value in USD = 20000e18 (2000e8 * 1e10 * 10e18 / 1e18)
        // Liquidation threshold = 20000e18 * 0.5 = 10000e18
        // DSC Amount = 100e18
        // Health Factor = 10000e18 / 100e18 = 100e18
        uint256 expectedHealthFactor = 100 ether;
        // Get the actual health factor
        uint256 actualHealthFactor = dscEngine.calculateHealthFactor(
            DSC_AMOUNT,
            dscEngine.getUsdValueOfCollateral(weth, COLLATERAL_AMOUNT)
        );
        assertEq(
            actualHealthFactor,
            expectedHealthFactor,
            "Health Factor should match expected value"
        );
    }

    function testHealthFactorIsBelowOne()
        public
        depositedCollateralAndMintedDSC
    {
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        // Rememeber, we need $200 at all times if we have $100 of debt

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        uint256 userHealthFactor = dscEngine.calculateHealthFactor(
            DSC_AMOUNT,
            dscEngine.getUsdValueOfCollateral(weth, COLLATERAL_AMOUNT)
        );
        // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
        // 0.9
        assert(userHealthFactor == 0.9 ether);
    }

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////

    function testMustImproveHealthFactorOnLiquidation() public {
        // Arrange - Setup
        MockMoreDebtDSC mockDsc = new MockMoreDebtDSC(ethUsdPriceFeed);
        tokenAddresses = [weth];
        priceFeedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockDscEngine = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockDsc)
        );
        mockDsc.transferOwnership(address(mockDscEngine));
        // Arrange - User
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockDscEngine), COLLATERAL_AMOUNT);
        // Collateral Value in USD = 20000e18 (2000e8 * 1e10 * 10e18 / 1e18)
        // Liquidation threshold = 20000e18 * 0.5 = 10000e18
        // DSC Amount = 100e18
        // Health Factor = 10000e18 / 100e18 = 100e18
        // The user has a health factor of 100 corresponding to a liquidation threshold of 10000e18 for a collateral value of 20000e18 and a DSC amount of 100e18
        mockDscEngine.depositCollateralAndMintDSC(
            weth,
            COLLATERAL_AMOUNT,
            DSC_AMOUNT
        );
        vm.stopPrank();

        // Arrange - Liquidator
        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(mockDscEngine), collateralToCover);
        uint256 debtToCover = 10 ether; // 10 DSC or $10e18 in wei
        // The liquidator has deposited 1 ether of collateral to cover 10 DSC or $10e18 in debt. They are minting 100 however, which represents $100e18 in debt owed by the user.
        mockDscEngine.depositCollateralAndMintDSC(
            weth,
            collateralToCover,
            DSC_AMOUNT
        );
        // approve the transfer of 10 DSC from the liquidators DSC account to the DSC engine
        mockDsc.approve(address(mockDscEngine), debtToCover);
        // Act - Crash the price of ETH to $18 to make the health factor worse.
        // Health Factor = (180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION)) / 100 (DSC_AMOUNT) = 90 / 100 (totalDscMinted) = 0.9
        // The health factor is now 0.9, which is below the liquidation threshold of 1.0
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        // Act/Assert
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        mockDscEngine.liquidate(weth, USER, debtToCover);
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealthFactor()
        public
        depositedCollateralAndMintedDSC
    {
        // Arrange - Liquidator
        // Mint some ether to the liquidator
        ERC20Mock(weth).mint(liquidator, collateralToCover);
        vm.startPrank(liquidator);
        // Approve the transfer of the collateral to the DSCEngine contract
        ERC20Mock(weth).approve(address(dscEngine), collateralToCover);
        // Deposit the collateral to the DSCEngine contract
        dscEngine.depositCollateralAndMintDSC(
            weth,
            collateralToCover,
            DSC_AMOUNT
        );
        // Approve the transfer of DSC to the DSCEngine contract
        dsc.approve(address(dscEngine), DSC_AMOUNT);
        // Act/Assert
        vm.expectRevert(
            DSCEngine.DSCEngine__HealthFactorIsAboveThreshold.selector
        );
        dscEngine.liquidate(weth, USER, DSC_AMOUNT);
        vm.stopPrank();
    }

    /**
     * @notice Test that the liquidator can liquidate the user
     * @notice I'm not sure if this is a bug but the user still has a DSC balance after liquidation
     * @notice The liquidator should have a DSC balance after liquidation equal to the amount of collateral they redeemed from the user which is not the case - to be checked.
     * @notice The user should have a DSC balance of 0 after liquidation which is not the case - to be checked.
     */

    function testCanLiquidate() public liquidated {
        // Check the user's DSC balance after liquidation
        console.log(
            "User's DSC balance after liquidation: ",
            dsc.balanceOf(USER)
        ); // 100000000000000000000 [why is this not 0?]
        assertEq(dsc.balanceOf(USER), DSC_AMOUNT);
        // Check the liquidator's DSC balance after liquidation
        console.log(
            "Liquidator's DSC balance after liquidation: ",
            dsc.balanceOf(liquidator)
        ); // 0 [to be expected because they burned the DSC to redeem the collateral]
        assertEq(dsc.balanceOf(liquidator), 0);

        // Check the liquidator's collateral balance after liquidation
        console.log(
            "Liquidator's WETH balance after liquidation: ",
            ERC20Mock(weth).balanceOf(liquidator)
        ); // 6111111111111111110 [110/180]
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = dscEngine.getCollateralAmountFromUSDValue(
            weth,
            DSC_AMOUNT
        ) +
            (dscEngine.getCollateralAmountFromUSDValue(weth, DSC_AMOUNT) /
                dscEngine.getLiquidationBonus());
        assertEq(liquidatorWethBalance, expectedWeth);
        // Check that the liquidator takes on the user's debt

        console.log(
            "Liquidators's DSC balance after liquidation: ",
            dscEngine.getDscMintedAmount(liquidator)
        ); // 0
        (uint256 liquidatorDscMinted, ) = dscEngine.getAccountInformation(
            liquidator
        );
        assertEq(liquidatorDscMinted, DSC_AMOUNT);
        // Assert - Check the user's DSC balance in the s_userDscMinted
        console.log(
            "User's DSC balance after liquidation: ",
            dscEngine.getDscMintedAmount(USER)
        ); // 0
        (uint256 userDscMinted, ) = dscEngine.getAccountInformation(USER);
        assertEq(userDscMinted, 0);
    }

    // The following two tests are a breakdown of the liquidation test above

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        // Check the liquidator's DSC balance
        (uint256 liquidatorDscMinted, ) = dscEngine.getAccountInformation(
            liquidator
        );
        // uint256 liquidatorDscMinted = dscEngine.getDscMintedAmount(liquidator);
        assertEq(liquidatorDscMinted, DSC_AMOUNT);
    }

    function testUserHasNoDebtAfterLiquidation() public liquidated {
        // Check the user's DSC balance
        (uint256 userDscMinted, ) = dscEngine.getAccountInformation(USER);
        console.log(
            "User's DSC balance on DSCEngine after liquidation: ",
            userDscMinted
        );
        // uint256 userDscMinted = dscEngine.getDscMintedAmount(USER);
        assertEq(userDscMinted, 0);
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        // Check the liquidators balance
        console.log(
            "Liquidator's WETH balance after liquidation: ",
            ERC20Mock(weth).balanceOf(liquidator)
        );
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = dscEngine.getCollateralAmountFromUSDValue(
            weth,
            DSC_AMOUNT
        ) +
            (dscEngine.getCollateralAmountFromUSDValue(weth, DSC_AMOUNT) /
                dscEngine.getLiquidationBonus());
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        // Assert that the liquidator's balance is equal to the expected value
        assertEq(liquidatorWethBalance, expectedWeth);
        assertEq(liquidatorWethBalance, hardCodedExpected);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // retrieve the user's balance to see how much they have lost
        uint256 amountLiquidated = dscEngine.getCollateralAmountFromUSDValue(
            weth,
            DSC_AMOUNT
        ) +
            (dscEngine.getCollateralAmountFromUSDValue(weth, DSC_AMOUNT) /
                dscEngine.getLiquidationBonus());
        // get the usd value of the amount liquidated
        uint256 usdValueOfAmountLiquidated = dscEngine.getUsdValueOfCollateral(
            weth,
            amountLiquidated
        );
        uint256 expectedUserCollateralBalanceInUsd = dscEngine
            .getUsdValueOfCollateral(weth, COLLATERAL_AMOUNT) -
            usdValueOfAmountLiquidated;

        // get the user's collateral balance
        (, uint256 collateralValInUsd) = dscEngine.getAccountInformation(USER);
        console.log(
            "User's collateral balance in USD after liquidation: ",
            collateralValInUsd
        ); // 70000000000000000020 [The user lost 6.1 eth in collateral and has 3.9eth left at $18 each]
        uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
        // Assert that the user's balance is equal to the expected value
        assertEq(collateralValInUsd, expectedUserCollateralBalanceInUsd);
        assertEq(collateralValInUsd, hardCodedExpectedValue);
    }

    ///////////////////////////////////
    // View & Pure Function Tests //
    //////////////////////////////////

    function testGetTokenCollateralPriceFeed() public view {
        address priceFeed = dscEngine.getPriceFeed(weth);
        assertEq(priceFeed, ethUsdPriceFeed);
    }

    function testGetCollateralTokens() public view {
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        assertEq(collateralTokens.length, 3);
        assertEq(collateralTokens[0], weth);
    }

    function testGetMinHealthFactor() public view {
        uint256 minHealthFactor = dscEngine.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public view {
        uint256 liquidationThreshold = dscEngine.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetUserHealthFactor() public depositedCollateralAndMintedDSC {
        uint256 userHealthFactor = dscEngine.getHealthFactor(USER);
        assertEq(userHealthFactor, 100e18);
    }

    function testGetAccountCollateralValueFromInformation()
        public
        depositedCollateral
    {
        (, uint256 collateralValue) = dscEngine.getAccountInformation(USER);
        uint256 expectedCollateralValue = dscEngine.getUsdValueOfCollateral(
            weth,
            COLLATERAL_AMOUNT
        );
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public depositedCollateral {
        uint256 userCollateralBalance = dscEngine.getDepositedCollateralAmount(
            USER,
            weth
        );
        assertEq(userCollateralBalance, COLLATERAL_AMOUNT);
    }

    function testGetDscMintedAmount() public depositedCollateralAndMintedDSC {
        uint256 dscMintedAmount = dscEngine.getDscMintedAmount(USER);
        assertEq(dscMintedAmount, DSC_AMOUNT);
    }

    function testGetAccountCollateralValue() public depositedCollateral {
        uint256 collateralValue = dscEngine.getAccountCollateralValueInUsd(
            USER
        );
        uint256 expectedCollateralValue = dscEngine.getUsdValueOfCollateral(
            weth,
            COLLATERAL_AMOUNT
        );
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetDscContract() public view {
        address dscContract = dscEngine.getDscContract();
        assertEq(dscContract, address(dsc));
    }

    function testLiquidationPrecision() public view {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = dscEngine.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }



    
}
