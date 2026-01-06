// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ILendMachine} from "./interfaces/ILendMachine.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";

/**
 * @title LendMachine
 * @notice A decentralized lending protocol for overcollateralized borrowing
 * @dev Allows users to deposit collateral and borrow against it
 */
contract LendMachine is ILendMachine, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Precision for percentage calculations (100% = 1e18)
    uint256 public constant PRECISION = 1e18;

    /// @notice Seconds per year for interest calculations
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /// @notice Minimum health factor before liquidation (1.0 = 1e18)
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    // ============ State Variables ============

    /// @notice The collateral token
    IERC20 public collateralToken;

    /// @notice The borrow token
    IERC20 public borrowToken;

    /// @notice The price oracle
    IPriceOracle public priceOracle;

    /// @notice The rewards distributor
    IRewardsDistributor public rewardsDistributor;

    /// @notice Loan-to-value ratio (75% = 0.75e18)
    uint256 public ltv = 75e16;

    /// @notice Liquidation threshold (80% = 0.80e18)
    uint256 public liquidationThreshold = 80e16;

    /// @notice Liquidation bonus (10% = 0.10e18)
    uint256 public liquidationBonus = 10e16;

    /// @notice Annual interest rate (5% = 0.05e18)
    uint256 public interestRate = 5e16;

    /// @notice Total collateral deposited
    uint256 public totalCollateral;

    /// @notice Total amount borrowed
    uint256 public totalBorrowed;

    /// @notice User positions
    mapping(address => Position) public positions;

    // ============ Constructor ============

    /**
     * @notice Constructor
     * @param _collateralToken The collateral token address
     * @param _borrowToken The borrow token address
     * @param _priceOracle The price oracle address
     * @param initialOwner The initial owner of the contract
     */
    constructor(
        address _collateralToken,
        address _borrowToken,
        address _priceOracle,
        address initialOwner
    ) Ownable(initialOwner) {
        require(_collateralToken != address(0), "LendMachine: invalid collateral token");
        require(_borrowToken != address(0), "LendMachine: invalid borrow token");
        require(_priceOracle != address(0), "LendMachine: invalid oracle");

        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
        priceOracle = IPriceOracle(_priceOracle);
    }

    // ============ External Functions ============

    /**
     * @notice Sets the rewards distributor
     * @param _rewardsDistributor The rewards distributor address
     */
    function setRewardsDistributor(address _rewardsDistributor) external onlyOwner {
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
    }

    /**
     * @notice Deposits collateral into the protocol
     * @param amount The amount of collateral to deposit
     */
    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "LendMachine: zero amount");

        // Transfer collateral from user
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update position
        Position storage position = positions[msg.sender];
        position.collateralAmount += amount;
        totalCollateral += amount;

        // Accrue rewards
        if (address(rewardsDistributor) != address(0)) {
            rewardsDistributor.accrueRewards(msg.sender, position.collateralAmount);
        }

        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Withdraws collateral from the protocol
     * @param amount The amount of collateral to withdraw
     */
    function withdraw(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "LendMachine: zero amount");

        Position storage position = positions[msg.sender];
        require(position.collateralAmount >= amount, "LendMachine: insufficient collateral");

        // Accrue interest before checking health factor
        _accrueInterest(msg.sender);

        // Notify rewards distributor (external call)
        if (address(rewardsDistributor) != address(0)) {
            rewardsDistributor.accrueRewards(msg.sender, position.collateralAmount - amount);
        }

        // Update position
        position.collateralAmount -= amount;
        totalCollateral -= amount;

        // Check health factor after withdrawal
        if (position.borrowedAmount > 0) {
            require(healthFactor(msg.sender) >= MIN_HEALTH_FACTOR, "LendMachine: unhealthy position");
        }

        // Transfer collateral to user
        collateralToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Borrows tokens against deposited collateral
     * @param amount The amount to borrow
     */
    function borrow(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "LendMachine: zero amount");

        Position storage position = positions[msg.sender];
        require(position.collateralAmount > 0, "LendMachine: no collateral");

        // Accrue interest on existing debt
        _accrueInterest(msg.sender);

        // Check if borrow is within limits
        uint256 maxBorrow = maxBorrowable(msg.sender);
        require(amount <= maxBorrow, "LendMachine: exceeds max borrow");

        // Update position
        position.borrowedAmount += amount;
        position.lastInterestAccrual = block.timestamp;
        totalBorrowed += amount;

        // Transfer borrowed tokens to user
        borrowToken.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    /**
     * @notice Repays borrowed tokens
     * @param amount The amount to repay
     */
    function repay(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "LendMachine: zero amount");

        Position storage position = positions[msg.sender];
        require(position.borrowedAmount > 0, "LendMachine: no debt");

        // Accrue interest before repayment
        _accrueInterest(msg.sender);

        // Calculate actual repayment amount
        uint256 actualRepayment = amount > position.borrowedAmount ? position.borrowedAmount : amount;

        // Transfer tokens from user
        borrowToken.safeTransferFrom(msg.sender, address(this), actualRepayment);

        // Update position
        position.borrowedAmount -= actualRepayment;
        totalBorrowed -= actualRepayment;

        emit Repaid(msg.sender, actualRepayment);
    }

    /**
     * @notice Liquidates an unhealthy position
     * @param user The user whose position to liquidate
     * @param debtAmount The amount of debt to repay
     */
    function liquidate(address user, uint256 debtAmount) external whenNotPaused nonReentrant {
        require(user != address(0), "LendMachine: invalid user");
        require(debtAmount > 0, "LendMachine: zero amount");

        Position storage position = positions[user];
        require(position.borrowedAmount > 0, "LendMachine: no debt");

        // Accrue interest before liquidation
        _accrueInterest(user);

        // Check if position is liquidatable
        require(healthFactor(user) < MIN_HEALTH_FACTOR, "LendMachine: healthy position");

        // Cap debt repayment at 50% of total debt (partial liquidation)
        uint256 maxLiquidation = position.borrowedAmount / 2;
        uint256 actualDebtRepayment = debtAmount > maxLiquidation ? maxLiquidation : debtAmount;

        // Calculate collateral to seize
        uint256 collateralPrice = priceOracle.getPrice(address(collateralToken));
        uint256 borrowPrice = priceOracle.getPrice(address(borrowToken));

        // Debt value in USD
        uint256 debtValueUsd = (actualDebtRepayment * borrowPrice) / 1e8;

        // Collateral to seize = debt value * (1 + liquidation bonus) / collateral price
        uint256 collateralToSeize = (debtValueUsd * (PRECISION + liquidationBonus)) / collateralPrice;
        collateralToSeize = (collateralToSeize * 1e8) / PRECISION;

        // Ensure we don't seize more than available
        if (collateralToSeize > position.collateralAmount) {
            collateralToSeize = position.collateralAmount;
        }

        // Transfer debt tokens from liquidator
        borrowToken.safeTransferFrom(msg.sender, address(this), actualDebtRepayment);

        // Update position
        position.borrowedAmount -= actualDebtRepayment;
        position.collateralAmount -= collateralToSeize;
        totalBorrowed -= actualDebtRepayment;
        totalCollateral -= collateralToSeize;

        // Transfer seized collateral to liquidator
        collateralToken.safeTransfer(msg.sender, collateralToSeize);

        emit Liquidated(msg.sender, user, actualDebtRepayment, collateralToSeize);
    }

    /**
     * @notice Sets the interest rate
     * @param rate The new interest rate
     */
    function setInterestRate(uint256 rate) external {
        // Update interest rate
        require(rate <= 1e18, "LendMachine: rate too high");
        interestRate = rate;
        emit InterestRateUpdated(rate);
    }

    /**
     * @notice Sets protocol parameters
     * @param _ltv The new loan-to-value ratio
     * @param _liquidationThreshold The new liquidation threshold
     * @param _liquidationBonus The new liquidation bonus
     */
    function setParameters(
        uint256 _ltv,
        uint256 _liquidationThreshold,
        uint256 _liquidationBonus
    ) external onlyOwner {
        require(_ltv < _liquidationThreshold, "LendMachine: invalid ltv");
        require(_liquidationThreshold <= PRECISION, "LendMachine: invalid threshold");
        require(_liquidationBonus <= 50e16, "LendMachine: bonus too high");

        ltv = _ltv;
        liquidationThreshold = _liquidationThreshold;
        liquidationBonus = _liquidationBonus;
    }

    /**
     * @notice Pauses the protocol
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the protocol
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Callback when user receives rewards
     * @param user The user who received rewards
     * @param amount The amount received
     */
    function onRewardsReceived(address user, uint256 amount) external {
        require(msg.sender == address(rewardsDistributor), "LendMachine: unauthorized");
        // Hook for future integrations
        // Could be used to auto-compound rewards or update internal accounting
    }

    // ============ View Functions ============

    /**
     * @notice Returns a user's position
     * @param user The user address
     * @return The user's position
     */
    function getPosition(address user) external view returns (Position memory) {
        return positions[user];
    }

    /**
     * @notice Calculates the health factor of a user's position
     * @param user The user address
     * @return The health factor (1e18 = 100%)
     */
    function healthFactor(address user) public view returns (uint256) {
        Position storage position = positions[user];

        if (position.borrowedAmount == 0) {
            return type(uint256).max;
        }

        // Get prices
        uint256 collateralPrice = priceOracle.getPrice(address(collateralToken));
        uint256 borrowPrice = priceOracle.getPrice(address(borrowToken));

        // Calculate collateral value in USD
        uint256 collateralValueUsd = (position.collateralAmount * collateralPrice) / 1e8;

        // Calculate liquidation threshold value
        uint256 thresholdValue = (collateralValueUsd * liquidationThreshold) / PRECISION;

        // Calculate debt with accrued interest
        uint256 debtWithInterest = _calculateDebtWithInterest(user);
        uint256 debtValueUsd = (debtWithInterest * borrowPrice) / 1e8;

        // Health factor = threshold value / debt value
        return (thresholdValue * PRECISION) / debtValueUsd;
    }

    /**
     * @notice Calculates the maximum borrowable amount for a user
     * @param user The user address
     * @return The maximum amount that can be borrowed
     */
    function maxBorrowable(address user) public view returns (uint256) {
        Position storage position = positions[user];

        // Get prices
        uint256 collateralPrice = priceOracle.getPrice(address(collateralToken));
        uint256 borrowPrice = priceOracle.getPrice(address(borrowToken));

        // Calculate collateral value in USD
        uint256 collateralValueUsd = (position.collateralAmount * collateralPrice) / 1e8;

        // Calculate max borrow value in USD
        uint256 maxBorrowValueUsd = (collateralValueUsd * ltv) / PRECISION;

        // Calculate current debt with interest
        uint256 currentDebtWithInterest = _calculateDebtWithInterest(user);
        uint256 currentDebtValueUsd = (currentDebtWithInterest * borrowPrice) / 1e8;

        // Return available borrow amount
        if (currentDebtValueUsd >= maxBorrowValueUsd) {
            return 0;
        }

        uint256 availableValueUsd = maxBorrowValueUsd - currentDebtValueUsd;
        return (availableValueUsd * 1e8) / borrowPrice;
    }

    // ============ Internal Functions ============

    /**
     * @notice Accrues interest on a user's position
     * @param user The user address
     */
    function _accrueInterest(address user) internal {
        Position storage position = positions[user];

        if (position.borrowedAmount == 0 || position.lastInterestAccrual == 0) {
            position.lastInterestAccrual = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - position.lastInterestAccrual;
        if (timeElapsed == 0) {
            return;
        }

        // Calculate interest
        // Interest = principal * rate * time / seconds_per_year
        uint256 interest = (position.borrowedAmount * interestRate * timeElapsed) / (PRECISION * SECONDS_PER_YEAR);

        // Add interest to borrowed amount
        position.borrowedAmount += interest;
        totalBorrowed += interest;
        position.lastInterestAccrual = block.timestamp;
    }

    /**
     * @notice Calculates debt with accrued interest (view)
     * @param user The user address
     * @return The total debt including interest
     */
    function _calculateDebtWithInterest(address user) internal view returns (uint256) {
        Position storage position = positions[user];

        if (position.borrowedAmount == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - position.lastInterestAccrual;
        uint256 interest = (position.borrowedAmount * interestRate * timeElapsed) / (PRECISION * SECONDS_PER_YEAR);

        return position.borrowedAmount + interest;
    }
}
