// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";

/**
 * @title AggregatorV3Interface
 * @notice Minimal Chainlink aggregator interface
 */
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function decimals() external view returns (uint8);
}

/**
 * @title PriceOracle
 * @notice Oracle wrapper for fetching token prices from Chainlink feeds
 * @dev Aggregates price data from multiple Chainlink price feeds
 */
contract PriceOracle is IPriceOracle, Ownable {
    /// @notice Mapping of token addresses to their Chainlink price feeds
    mapping(address => address) public priceFeeds;

    /// @notice Price precision (8 decimals to match Chainlink)
    uint256 public constant PRICE_PRECISION = 1e8;

    /// @notice Emitted when a price feed is set
    event PriceFeedSet(address indexed token, address indexed priceFeed);

    /**
     * @notice Constructor
     * @param initialOwner The initial owner of the contract
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @notice Sets the price feed for a token
     * @param token The token address
     * @param priceFeed The Chainlink price feed address
     */
    function setPriceFeed(address token, address priceFeed) external onlyOwner {
        require(token != address(0), "PriceOracle: invalid token");
        require(priceFeed != address(0), "PriceOracle: invalid price feed");
        priceFeeds[token] = priceFeed;
        emit PriceFeedSet(token, priceFeed);
    }

    /**
     * @notice Returns the price feed address for a token
     * @param token The token address
     * @return The price feed address
     */
    function getPriceFeed(address token) external view returns (address) {
        return priceFeeds[token];
    }

    /**
     * @notice Returns the latest price for a token
     * @param token The token address
     * @return price The price in USD with 8 decimals
     */
    function getPrice(address token) external view returns (uint256 price) {
        address priceFeed = priceFeeds[token];
        require(priceFeed != address(0), "PriceOracle: no price feed");

        (
            ,
            int256 answer,
            ,
            ,
        ) = AggregatorV3Interface(priceFeed).latestRoundData();

        require(answer > 0, "PriceOracle: invalid price");

        // Normalize to 8 decimals if needed
        uint8 feedDecimals = AggregatorV3Interface(priceFeed).decimals();
        if (feedDecimals < 8) {
            price = uint256(answer) * (10 ** (8 - feedDecimals));
        } else if (feedDecimals > 8) {
            price = uint256(answer) / (10 ** (feedDecimals - 8));
        } else {
            price = uint256(answer);
        }
    }

    /**
     * @notice Returns the price and timestamp for a token
     * @param token The token address
     * @return price The price in USD with 8 decimals
     * @return updatedAt The timestamp of the last update
     */
    function getPriceWithTimestamp(address token) external view returns (uint256 price, uint256 updatedAt) {
        address priceFeed = priceFeeds[token];
        require(priceFeed != address(0), "PriceOracle: no price feed");

        (
            ,
            int256 answer,
            ,
            uint256 timestamp,
        ) = AggregatorV3Interface(priceFeed).latestRoundData();

        require(answer > 0, "PriceOracle: invalid price");

        uint8 feedDecimals = AggregatorV3Interface(priceFeed).decimals();
        if (feedDecimals < 8) {
            price = uint256(answer) * (10 ** (8 - feedDecimals));
        } else if (feedDecimals > 8) {
            price = uint256(answer) / (10 ** (feedDecimals - 8));
        } else {
            price = uint256(answer);
        }

        updatedAt = timestamp;
    }
}
