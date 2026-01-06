// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPriceOracle
 * @notice Interface for the price oracle used by LendMachine
 * @dev Provides price feeds for collateral and debt tokens
 */
interface IPriceOracle {
    /**
     * @notice Returns the latest price for a given token
     * @param token The token address to get the price for
     * @return price The price in USD with 8 decimals
     */
    function getPrice(address token) external view returns (uint256 price);

    /**
     * @notice Returns the price and the timestamp of the last update
     * @param token The token address to get the price for
     * @return price The price in USD with 8 decimals
     * @return updatedAt The timestamp of the last price update
     */
    function getPriceWithTimestamp(address token) external view returns (uint256 price, uint256 updatedAt);

    /**
     * @notice Sets the price feed address for a token
     * @param token The token address
     * @param priceFeed The Chainlink price feed address
     */
    function setPriceFeed(address token, address priceFeed) external;

    /**
     * @notice Returns the price feed address for a token
     * @param token The token address
     * @return The price feed address
     */
    function getPriceFeed(address token) external view returns (address);
}
