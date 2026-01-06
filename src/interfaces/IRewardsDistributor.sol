// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRewardsDistributor
 * @notice Interface for the rewards distribution system
 * @dev Handles bonus rewards for protocol participants
 */
interface IRewardsDistributor {
    /**
     * @notice Emitted when rewards are claimed
     * @param user The user claiming rewards
     * @param amount The amount of rewards claimed
     */
    event RewardsClaimed(address indexed user, uint256 amount);

    /**
     * @notice Emitted when rewards are accrued for a user
     * @param user The user receiving rewards
     * @param amount The amount of rewards accrued
     */
    event RewardsAccrued(address indexed user, uint256 amount);

    /**
     * @notice Claims pending rewards for the caller
     * @return amount The amount of rewards claimed
     */
    function claimRewards() external returns (uint256 amount);

    /**
     * @notice Returns the pending rewards for a user
     * @param user The user address
     * @return The pending reward amount
     */
    function pendingRewards(address user) external view returns (uint256);

    /**
     * @notice Accrues rewards for a user based on their activity
     * @param user The user address
     * @param amount The base amount for reward calculation
     */
    function accrueRewards(address user, uint256 amount) external;

    /**
     * @notice Sets the reward rate (rewards per token per second)
     * @param rate The new reward rate
     */
    function setRewardRate(uint256 rate) external;

    /**
     * @notice Returns the current reward rate
     * @return The reward rate
     */
    function rewardRate() external view returns (uint256);

    /**
     * @notice Callback function called after rewards are claimed
     * @dev Used for integration with other protocol components
     * @param user The user who claimed rewards
     * @param amount The amount claimed
     */
    function onRewardsClaimed(address user, uint256 amount) external;
}
