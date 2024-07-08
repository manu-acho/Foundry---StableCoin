// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {Test, console} from "forge-std/Test.sol";
// import {DeployDSC} from "script/DeployDSC.s.sol";
// import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
// import {DSCEngine} from "src/DSCEngine.sol";
// import {HelperConfig} from "script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// /**
//  * @title OpenInvariantsTest
//  * @notice This contract tests the invariants of the DecentralizedStableCoin protocol
//  * @dev The contract is an illustration of how to test the invariants of the DecentralizedStableCoin protocol using an open testing methodology
//  * @dev In the open testing methodology all we have to do is specify the target contract and the invariants to test (more collateral value than total supply of dsc in this case)
//  * @dev This methodology will only work for this protocol if "fail_on_revert" is set to false in the forge-std configuration file
//  * @dev It is preferable to work with handlers in a closed testing methodology.
//  * @dev Remember to update this notice with information about the handlers used in the closed testing methodology
//     */

// contract OpenInvariantsTest is StdInvariant, Test {
//     DeployDSC deployer;
//     DecentralizedStableCoin dsc;
//     DSCEngine dscEngine;
//     HelperConfig helperConfig;
//     address weth;
//     address wbtc;

//     function setUp() public {
//         deployer = new DeployDSC();
//         (dsc, dscEngine, helperConfig) = deployer.run();
//         targetContract(address(dscEngine));
//         (, , weth, wbtc, ) = helperConfig.activeNetworkConfig();
//     }

// // Test that the protocol has more value in collateral than the total supply of dsc

// function invariant_protocolMustHaveMoreCollateralValueThanTotalDscSupply() public view {
//     // get the value of all collateral deposited in the protocol and compare it to the total supply of dsc representing debt
//     // get the total supply of dsc
//     uint256 totalDscMinted = dsc.totalSupply();
//     // get the volume of all collateral deposited in the protocol
//     uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
//     uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));
//     // get the value of all collateral deposited in the protocol
//     uint256 wethValue = dscEngine.getUsdValueOfCollateral(weth, totalWethDeposited);
//     uint256 wbtcValue = dscEngine.getUsdValueOfCollateral(wbtc, totalWbtcDeposited);
//     console.log("wethValue: ", wethValue);
//     console.log("wbtcValue: ", wbtcValue);
//     console.log("totalDscMinted: ", totalDscMinted);
//     // compare the value of all collateral deposited in the protocol to the total supply of dsc
//     assert(wethValue + wbtcValue >= totalDscMinted);

// }

// }
