// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILendMachine
 * @notice Interface for the LendMachine lending protocol
 * @dev Core lending and borrowing functionality
 */
interface ILendMachine {
    // ============ Structs ============

    /**
     * @notice Represents a user's position in the protocol
     * @param collateralAmount Amount of collateral deposited
     * @param borrowedAmount Amount of tokens borrowed
     * @param lastInterestAccrual Timestamp of last interest accrual
     */
    struct Position {
        uint256 collateralAmount;
        uint256 borrowedAmount;
        uint256 lastInterestAccrual;
    }

    // ============ Events ============

    /**
     * @notice Emitted when collateral is deposited
     */
    event Deposited(address indexed user, uint256 amount);

    /**
     * @notice Emitted when collateral is withdrawn
     */
    event Withdrawn(address indexed user, uint256 amount);

    /**
     * @notice Emitted when tokens are borrowed
     */
    event Borrowed(address indexed user, uint256 amount);

    /**
     * @notice Emitted when borrowed tokens are repaid
     */
    event Repaid(address indexed user, uint256 amount);

    /**
     * @notice Emitted when a position is liquidated
     */
    event Liquidated(
        address indexed liquidator,
        address indexed user,
        uint256 debtRepaid,
        uint256 collateralSeized
    );

    /**
     * @notice Emitted when interest rate is updated
     */
    event InterestRateUpdated(uint256 newRate);

    // ============ Core Functions ============

    /**
     * @notice Deposits collateral into the protocol
     * @param amount The amount of collateral to deposit
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Withdraws collateral from the protocol
     * @param amount The amount of collateral to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Borrows tokens against deposited collateral
     * @param amount The amount to borrow
     */
    function borrow(uint256 amount) external;

    /**
     * @notice Repays borrowed tokens
     * @param amount The amount to repay
     */
    function repay(uint256 amount) external;

    /**
     * @notice Liquidates an unhealthy position
     * @param user The user whose position to liquidate
     * @param debtAmount The amount of debt to repay
     */
    function liquidate(address user, uint256 debtAmount) external;

    // ============ View Functions ============

    /**
     * @notice Returns a user's position
     * @param user The user address
     * @return The user's position
     */
    function getPosition(address user) external view returns (Position memory);

    /**
     * @notice Returns the health factor of a user's position
     * @param user The user address
     * @return The health factor (1e18 = 100%)
     */
    function healthFactor(address user) external view returns (uint256);

    /**
     * @notice Returns the maximum borrowable amount for a user
     * @param user The user address
     * @return The maximum amount that can be borrowed
     */
    function maxBorrowable(address user) external view returns (uint256);

    /**
     * @notice Returns the current interest rate
     * @return The annual interest rate (1e18 = 100%)
     */
    function interestRate() external view returns (uint256);

    /**
     * @notice Returns the loan-to-value ratio
     * @return The LTV ratio (1e18 = 100%)
     */
    function ltv() external view returns (uint256);

    /**
     * @notice Returns the liquidation threshold
     * @return The liquidation threshold (1e18 = 100%)
     */
    function liquidationThreshold() external view returns (uint256);

    /**
     * @notice Returns the liquidation bonus
     * @return The liquidation bonus (1e18 = 100%)
     */
    function liquidationBonus() external view returns (uint256);

    // ============ Admin Functions ============

    /**
     * @notice Sets the interest rate
     * @param rate The new interest rate
     */
    function setInterestRate(uint256 rate) external;

    /**
     * @notice Pauses the protocol
     */
    function pause() external;

    /**
     * @notice Unpauses the protocol
     */
    function unpause() external;
}
