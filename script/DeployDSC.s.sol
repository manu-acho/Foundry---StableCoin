// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    //uint256[] public liquidationThresholds;  // Array for liquidation thresholds



    function run() external returns (DecentralizedStableCoin, DSCEngine,HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address xauUsdPriceFeed,
            address weth,
            address wbtc,
            address xaut,
            uint256 deployerKey
            //uint256 wethThreshold,
            //uint256 wbtcThreshold,
            //uint256 xautThreshold
        ) = helperConfig.activeNetworkConfig();

        tokenAddresses = [weth, wbtc, xaut];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed, xauUsdPriceFeed];
        //liquidationThresholds = [wethThreshold, wbtcThreshold, xautThreshold];  // Set the liquidation thresholds

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        
        DSCEngine dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc) /*, liquidationThresholds*/);
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (dsc, dscEngine, helperConfig);
    }
}
