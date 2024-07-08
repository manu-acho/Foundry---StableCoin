// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title OracleLib
 * @author Emmanuel Acho with special thanks to @PatrickAlphaC (Patrick Collins)
 * @notice This library checks the Chainlink oracle price feed for stale data
 * Stale data will cause the function to revert rendering the contract unusable by design
 */

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {

    error OracleLib__StalePriceData(); // Error for stale data

    uint256 private constant TIMEOUT = 3 hours; // 3 hours in seconds = 3 * 60 * 60

    /**
     * @notice This function checks the Chainlink oracle price feed for stale data
     * @param priceFeed The Chainlink oracle price feed
     * @return roundId The round ID
     * @return answer The price feed answer
     * @return startedAt The timestamp of the start of the round
     * @return updatedAt The timestamp of the last update
     * @return answeredInRound The round ID in which the answer was computed
     */

    function stalePriceCheckLatestRoundData(
        AggregatorV3Interface priceFeed
    ) public view returns (uint80, int256, uint256, uint256, uint80) {
        // Get the latest round data
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        // Check if the data is stale
        uint256 timeElapsed = block.timestamp - updatedAt;
        if (timeElapsed > TIMEOUT) {
            revert OracleLib__StalePriceData(); // Revert if the data is stale
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
