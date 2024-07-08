// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address xauUsdPriceFeed;
        address weth;
        address wbtc;
        address xaut; // gold token
        uint256 deployerKey;
        //uint256 wethLiquidationThreshold;
        //uint256 wbtcLiquidationThreshold;
        //uint256 xautLiquidationThreshold;
    }

    NetworkConfig public activeNetworkConfig;
    uint8 public constant DECIMALS = 8;
    int256 public constant WETH_USD_PRICE = 2000e8;
    int256 public constant WBTC_USD_PRICE = 1000e8;
    int256 public constant XAU_USD_PRICE = 2000e8;
    uint256 public DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
                xauUsdPriceFeed: 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea,
                weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
                wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
                xaut: 0x68749665FF8D2d112Fa859AA293F07A622782F38,
                deployerKey: vm.envUint("PRIVATE_KEY_SEP")
                //wethLiquidationThreshold: 80 // Representing 80%
                //wbtcLiquidationThreshold: 80 // Representing 80%
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
    // Create mock price feeds and tokens
        vm.startBroadcast();
        MockV3Aggregator wethUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            WETH_USD_PRICE
        );
        MockV3Aggregator wbtcUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            WBTC_USD_PRICE
        );
        MockV3Aggregator xauUsdPriceFeed = new MockV3Aggregator(DECIMALS, XAU_USD_PRICE);

        // MockV3Aggregator xauUsdPriceFeed = new MockV3Aggregator(DECIMALS, XAU_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock();
        ERC20Mock wbtcMock = new ERC20Mock();
        ERC20Mock xautMock = new ERC20Mock();
        // ERC20Mock xautMock = new ERC20Mock();
        vm.stopBroadcast();

        return
            NetworkConfig({
                wethUsdPriceFeed: address(wethUsdPriceFeed),
                wbtcUsdPriceFeed: address(wbtcUsdPriceFeed),
                xauUsdPriceFeed: address(xauUsdPriceFeed),
                weth: address(wethMock),
                wbtc: address(wbtcMock),
                xaut: address(xautMock),
                deployerKey: vm.envUint("DEFAULT_ANVIL_KEY")
                //wethLiquidationThreshold: 80 // Representing 80%
                //wbtcLiquidationThreshold: 80 // Representing 80%
                //xautLiquidationThreshold: 80 // Representing 80%
            });
    }
}
