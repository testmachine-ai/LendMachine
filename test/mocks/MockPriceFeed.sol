// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockPriceFeed
 * @notice A mock Chainlink price feed for testing purposes
 */
contract MockPriceFeed {
    int256 private _price;
    uint256 private _updatedAt;
    uint8 private _decimals;
    uint80 private _roundId;

    constructor(int256 initialPrice, uint8 decimals_) {
        _price = initialPrice;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
        _roundId = 1;
    }

    function setPrice(int256 price) external {
        _price = price;
        _updatedAt = block.timestamp;
        _roundId++;
    }

    function setPriceWithTimestamp(int256 price, uint256 timestamp) external {
        _price = price;
        _updatedAt = timestamp;
        _roundId++;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}
