// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "test/fuzz/Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
         (, , , weth, wbtc, , ) = helperConfig.activeNetworkConfig();
        // we need to make sure that functions in the target contract are called in a logical (right) order
        // For instance we can ony redeem collateral after we have deposited it or burn dsc after we have minted it
        // The handler will help us to enforce this order i.e., it handles the way calls are made to the actual target contract (dscEngine). What this means is rather than pass the DSC engine directly to the test, we pass the handler which will handle the calls to the DSC engine
        handler = new Handler(dscEngine, dsc);
        targetContract(address(handler));
    }

    // Test that the protocol has more value in collateral than the total supply of dsc representing debt

    function invariant_protocolMustHaveMoreCollateralValueThanTotalDscSupply()
        public
        view
    {
        // get the value of all collateral deposited in the protocol and compare it to the total supply of dsc representing debt
        // get the total supply of dsc (debt)
        uint256 totalDscMinted = dsc.totalSupply();
        // get the volume of all collateral deposited in the protocol
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));
        // get the value of all collateral deposited in the protocol
        uint256 wethValue = dscEngine.getUsdValueOfCollateral(
            weth,
            totalWethDeposited
        );
        uint256 wbtcValue = dscEngine.getUsdValueOfCollateral(
            wbtc,
            totalWbtcDeposited
        );
        console.log("wethValue: ", wethValue);
        console.log("wbtcValue: ", wbtcValue);
        console.log("totalDscMinted: ", totalDscMinted);
        console.log("Times mint is called: ", handler.timesMintIsCalled());
        // compare the value of all collateral deposited in the protocol to the total supply of dsc
        assert(wethValue + wbtcValue >= totalDscMinted);
    }

    function invariant_gettersShouldNotRevert() public view {
        // check that the getCollateralTokens function does not revert
        dscEngine.getCollateralTokens();
        // check that the getUsdValueOfCollateral function does not revert
        dscEngine.getUsdValueOfCollateral(weth, 1);
        dscEngine.getUsdValueOfCollateral(wbtc, 1);
        // check that getLiquidationBonus function does not revert
        dscEngine.getLiquidationBonus();
        // check that getAccountInformation function does not revert
        dscEngine.getAccountInformation(msg.sender);
        // check that getLiquidationThreshold function does not revert
        dscEngine.getLiquidationThreshold();
        
    }


}
