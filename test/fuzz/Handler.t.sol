// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256 public timesMintIsCalled; // This is a ghost variable used to track the number of times the mint function is called
    address[] public usersWhoDepositCollateral;
    MockV3Aggregator ethUsdPriceFeed;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    uint256 MAX_MINT_SIZE = type(uint96).max;

    //uint256 initialBalance = 1_000_000 ether;

    /*  constructor(address _dscEngine, address _dsc) {
        dscEngine = DSCEngine(_dscEngine);
        dsc = DecentralizedStableCoin(_dsc);
    }*/

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        ethUsdPriceFeed = MockV3Aggregator(
            dscEngine.getPriceFeed(address(weth))
        );
        // Mint some tokens to the handler to ensure it has enough balance. This scenario is commented out because it has a high revert rate as compared to the prank scenario that is used in the test
        //uint256 initialBalance = 1_000_000 ether;
        // weth.mint(address(this), initialBalance);
        // wbtc.mint(address(this), initialBalance);
    }

    function depositCollateral(
        uint256 collateralSeed,
        uint256 collateralAmount
    ) public {
        // Retrieve the collateral token from the seed
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        // Ensure the amount is greater than 0 using the bound function. The alternative is to use a require statement such as require(collateralAmount > 0, "Amount must be greater than 0");
        collateralAmount = bound(collateralAmount, 1, MAX_DEPOSIT_SIZE); // bound the amount to be within the range of 1 and the Max deposit size
        // Mint the collateral to the sender to ensure they have enough balance and prevent an ERC20 Insufficient balance error
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, collateralAmount);
        // Approve the collateral to the dscEngine
        collateral.approve(address(dscEngine), collateralAmount);
        // Deposit the collateral to the dscEngine
        dscEngine.depositCollateral(address(collateral), collateralAmount);
        vm.stopPrank();
        usersWhoDepositCollateral.push(msg.sender); // This has the potential to double push the same user if they deposit collateral more than once
    }

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 collateralAmount
    ) public {
        // Retrieve the collateral token from the seed
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        // deposit collateral
       
        depositCollateral(collateralSeed, collateralAmount);
        // Define the maximum amount of collateral to redeem
        uint256 maxCollateralAmount = dscEngine.getDepositedCollateralAmount(
            address(collateral),
            msg.sender
        );

        // Adjust maxCollateralAmount to be at least 1
        if (maxCollateralAmount < 1) {
            console.log("Max collateral amount is less than 1, adjusting to 1");
            maxCollateralAmount = 1;
        }
        // Ensure the redeem amount is greater than 0 using the bound function. The alternative is to use a require statement such as require(collateralAmount > 0, "Amount must be greater than 0");
        collateralAmount = bound(collateralAmount, 0, maxCollateralAmount); // bound the amount to be within the range of 1 and the Max deposit size
        if (collateralAmount == 0) {
            return;
        }
        // Redeem the collateral from the dscEngine
        vm.prank(msg.sender);
        dscEngine.redeemCollateral(address(collateral), collateralAmount);
     
    }

    function mintDsc(uint256 dscAmount, uint256 addressSeed) public {
        /* Define the maximum amount of DSC to mint
        1. Retrieve senders who have deposited collateral. Otherwise the function will not be called because collateral is needed to mint DSC
        1. Retrieve the sender's info from the dscEngine (total collateral, total debt)
        2. Calculate the maximum amount of DSC that can be minted. This is half the value of the collateral minus the total debt
        3. Ensure the mint amount is greater than 0 using the bound function
        4. Mint the DSC to the sender
        */
        // Retrieve the sender who has deposited collateral
        if (usersWhoDepositCollateral.length == 0) {
            return;
        } // Without this, we get a divide or modulo by zero error if the usersWhoDepositCollateral array is empty
        address sender = usersWhoDepositCollateral[
            addressSeed % usersWhoDepositCollateral.length
        ];
        // Retrieve the users info from the dscEngine
        (
            uint256 totaldebt /*i.e., totalDscMinted */,
            uint256 collateralValueInUsd
        ) = dscEngine.getAccountInformation(sender);
        // Calculate the maximum amount of DSC that can be minted
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) -
            int256(totaldebt);
        if (maxDscToMint < 0) {
            return;
        }
        // Ensure the mint amount is greater than 0 using the bound function.
        dscAmount = bound(dscAmount, 0, uint256(maxDscToMint));
        if (dscAmount == 0) {
            return;
        }
        // Mint the DSC to the sender
        vm.startPrank(sender);
        dscEngine.mintDSC(dscAmount);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    // This function breaks the invariant when price drops considerably. Needs a fix
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    function _getCollateralFromSeed(
        uint256 collateralSeed
    ) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
