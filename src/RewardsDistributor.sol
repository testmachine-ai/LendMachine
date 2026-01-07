// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";

/**
 * @title IRewardsCallback
 * @notice Interface for contracts that want to receive reward claim callbacks
 */
interface IRewardsCallback {
    function onRewardsReceived(address user, uint256 amount) external;
}

/**
 * @title IRewardAccrualCallback
 * @notice Interface for contracts that want to receive notifications when rewards are accrued
 * @dev Useful for smart contract wallets and composability with other protocols
 */
interface IRewardAccrualCallback {
    function onRewardsAccrued(address user, uint256 newDeposit, uint256 pendingRewards) external;
}

/**
 * @title RewardsDistributor
 * @notice Distributes bonus rewards to protocol participants
 * @dev Integrates with LendMachine to provide incentives for depositors
 */
contract RewardsDistributor is IRewardsDistributor, Ownable {
    using SafeERC20 for IERC20;

    /// @notice The reward token
    IERC20 public rewardToken;

    /// @notice The LendMachine contract (for callbacks)
    address public lendMachine;

    /// @notice Reward rate per token per second (scaled by 1e18)
    uint256 public rewardRate;

    /// @notice Pending rewards per user
    mapping(address => uint256) public pendingRewardsBalance;

    /// @notice Last reward accrual timestamp per user
    mapping(address => uint256) public lastAccrualTime;

    /// @notice User deposit amounts (synced from LendMachine)
    mapping(address => uint256) public userDeposits;

    /// @notice Callback recipients for reward accrual notifications
    mapping(address => address) public rewardCallbackRecipients;

    /// @notice Emitted when LendMachine address is set
    event LendMachineSet(address indexed lendMachine);

    /// @notice Emitted when a user sets their callback recipient
    event RewardCallbackSet(address indexed user, address indexed recipient);

    /// @notice Emitted when reward rate is updated
    event RewardRateUpdated(uint256 newRate);

    /**
     * @notice Constructor
     * @param _rewardToken The token used for rewards
     * @param initialOwner The initial owner of the contract
     */
    constructor(address _rewardToken, address initialOwner) Ownable(initialOwner) {
        require(_rewardToken != address(0), "RewardsDistributor: invalid token");
        rewardToken = IERC20(_rewardToken);
        rewardRate = 1e15; // Default: 0.001 tokens per token per second
    }

    /**
     * @notice Sets the LendMachine contract address
     * @param _lendMachine The LendMachine contract address
     */
    function setLendMachine(address _lendMachine) external onlyOwner {
        require(_lendMachine != address(0), "RewardsDistributor: invalid address");
        lendMachine = _lendMachine;
        emit LendMachineSet(_lendMachine);
    }

    /**
     * @notice Sets the reward rate
     * @param rate The new reward rate
     */
    function setRewardRate(uint256 rate) external onlyOwner {
        rewardRate = rate;
        emit RewardRateUpdated(rate);
    }

    /**
     * @notice Sets a callback recipient for reward accrual notifications
     * @dev Allows smart contract wallets to receive notifications when rewards are accrued
     * @param recipient The address to receive callbacks (set to address(0) to disable)
     */
    function setRewardCallback(address recipient) external {
        rewardCallbackRecipients[msg.sender] = recipient;
        emit RewardCallbackSet(msg.sender, recipient);
    }

    /**
     * @notice Accrues rewards for a user based on their deposit
     * @param user The user address
     * @param depositAmount The user's current deposit amount
     */
    function accrueRewards(address user, uint256 depositAmount) external {
        require(msg.sender == lendMachine, "RewardsDistributor: unauthorized");

        // Calculate pending rewards since last accrual
        if (lastAccrualTime[user] > 0 && userDeposits[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastAccrualTime[user];
            uint256 rewards = (userDeposits[user] * rewardRate * timeElapsed) / 1e18;
            pendingRewardsBalance[user] += rewards;
            emit RewardsAccrued(user, rewards);
        }

        // Notify callback recipient if set (for composability with smart contract wallets)
        address callback = rewardCallbackRecipients[user];
        if (callback != address(0)) {
            IRewardAccrualCallback(callback).onRewardsAccrued(user, depositAmount, pendingRewardsBalance[user]);
        }

        // Update state
        userDeposits[user] = depositAmount;
        lastAccrualTime[user] = block.timestamp;
    }

    /**
     * @notice Returns pending rewards for a user
     * @param user The user address
     * @return The pending reward amount
     */
    function pendingRewards(address user) external view returns (uint256) {
        uint256 pending = pendingRewardsBalance[user];

        // Add unclaimed rewards since last accrual
        if (lastAccrualTime[user] > 0 && userDeposits[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastAccrualTime[user];
            pending += (userDeposits[user] * rewardRate * timeElapsed) / 1e18;
        }

        return pending;
    }

    /**
     * @notice Claims pending rewards for the caller
     * @return amount The amount of rewards claimed
     */
    function claimRewards() external returns (uint256 amount) {
        // Calculate total pending rewards
        amount = pendingRewardsBalance[msg.sender];

        if (lastAccrualTime[msg.sender] > 0 && userDeposits[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastAccrualTime[msg.sender];
            amount += (userDeposits[msg.sender] * rewardRate * timeElapsed) / 1e18;
        }

        require(amount > 0, "RewardsDistributor: no rewards");

        // Reset pending rewards
        pendingRewardsBalance[msg.sender] = 0;
        lastAccrualTime[msg.sender] = block.timestamp;

        // Transfer rewards
        rewardToken.safeTransfer(msg.sender, amount);

        // Notify LendMachine about the claim (for any follow-up actions)
        if (lendMachine != address(0)) {
            // External call to notify about rewards claimed
            IRewardsCallback(lendMachine).onRewardsReceived(msg.sender, amount);
        }

        emit RewardsClaimed(msg.sender, amount);
    }

    /**
     * @notice Callback for when rewards are claimed
     * @dev Can be called by LendMachine to trigger additional reward logic
     * @param user The user who claimed
     * @param amount The amount claimed
     */
    function onRewardsClaimed(address user, uint256 amount) external {
        require(msg.sender == lendMachine, "RewardsDistributor: unauthorized");
        // Additional logic can be added here for composability
        // Currently used for event emission and potential future hooks
        emit RewardsClaimed(user, amount);
    }

    /**
     * @notice Emergency withdrawal of tokens by owner
     * @param token The token to withdraw
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}
