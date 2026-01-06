// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Setup} from "./Setup.t.sol";
import {ILendMachine} from "../src/interfaces/ILendMachine.sol";

/**
 * @title LendMachineTest
 * @notice Test suite for LendMachine core functionality
 */
contract LendMachineTest is Setup {
    // ============ Deposit Tests ============

    function test_deposit() public {
        uint256 depositAmount = 10e18;

        vm.prank(alice);
        lendMachine.deposit(depositAmount);

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.collateralAmount, depositAmount);
        assertEq(lendMachine.totalCollateral(), depositAmount);
    }

    function test_deposit_multipleDeposits() public {
        uint256 firstDeposit = 10e18;
        uint256 secondDeposit = 5e18;

        vm.startPrank(alice);
        lendMachine.deposit(firstDeposit);
        lendMachine.deposit(secondDeposit);
        vm.stopPrank();

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.collateralAmount, firstDeposit + secondDeposit);
    }

    function test_deposit_revertOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("LendMachine: zero amount");
        lendMachine.deposit(0);
    }

    // ============ Withdraw Tests ============

    function test_withdraw() public {
        uint256 depositAmount = 10e18;
        uint256 withdrawAmount = 5e18;

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.withdraw(withdrawAmount);
        vm.stopPrank();

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.collateralAmount, depositAmount - withdrawAmount);
    }

    function test_withdraw_full() public {
        uint256 depositAmount = 10e18;

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.withdraw(depositAmount);
        vm.stopPrank();

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.collateralAmount, 0);
    }

    function test_withdraw_revertOnInsufficientCollateral() public {
        uint256 depositAmount = 10e18;

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        vm.expectRevert("LendMachine: insufficient collateral");
        lendMachine.withdraw(depositAmount + 1);
        vm.stopPrank();
    }

    // ============ Borrow Tests ============

    function test_borrow() public {
        uint256 depositAmount = 10e18; // 10 WETH at $2000 = $20,000
        uint256 borrowAmount = 10_000e18; // $10,000 (50% LTV, well under 75% limit)

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.borrow(borrowAmount);
        vm.stopPrank();

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.borrowedAmount, borrowAmount);
        assertEq(lmToken.balanceOf(alice), 100_000e18 + borrowAmount);
    }

    function test_borrow_maxAmount() public {
        uint256 depositAmount = 10e18; // $20,000 collateral
        // Max borrow at 75% LTV = $15,000
        uint256 maxBorrow = lendMachine.maxBorrowable(alice);

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);

        uint256 actualMaxBorrow = lendMachine.maxBorrowable(alice);
        lendMachine.borrow(actualMaxBorrow);
        vm.stopPrank();

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.borrowedAmount, actualMaxBorrow);
    }

    function test_borrow_revertOnNoCollateral() public {
        vm.prank(alice);
        vm.expectRevert("LendMachine: no collateral");
        lendMachine.borrow(1000e18);
    }

    function test_borrow_revertOnExceedsMax() public {
        uint256 depositAmount = 10e18;

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);

        uint256 maxBorrow = lendMachine.maxBorrowable(alice);
        vm.expectRevert("LendMachine: exceeds max borrow");
        lendMachine.borrow(maxBorrow + 1);
        vm.stopPrank();
    }

    // ============ Repay Tests ============

    function test_repay() public {
        uint256 depositAmount = 10e18;
        uint256 borrowAmount = 5_000e18;
        uint256 repayAmount = 2_000e18;

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.borrow(borrowAmount);
        lendMachine.repay(repayAmount);
        vm.stopPrank();

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.borrowedAmount, borrowAmount - repayAmount);
    }

    function test_repay_full() public {
        uint256 depositAmount = 10e18;
        uint256 borrowAmount = 5_000e18;

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.borrow(borrowAmount);
        lendMachine.repay(borrowAmount);
        vm.stopPrank();

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.borrowedAmount, 0);
    }

    function test_repay_excessCapped() public {
        uint256 depositAmount = 10e18;
        uint256 borrowAmount = 5_000e18;

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.borrow(borrowAmount);

        uint256 balanceBefore = lmToken.balanceOf(alice);
        lendMachine.repay(borrowAmount * 2); // Try to repay more than owed
        uint256 balanceAfter = lmToken.balanceOf(alice);
        vm.stopPrank();

        // Should only have transferred the actual debt amount
        assertEq(balanceBefore - balanceAfter, borrowAmount);
    }

    // ============ Liquidation Tests ============

    function test_liquidate() public {
        uint256 depositAmount = 10e18; // $20,000 collateral
        uint256 borrowAmount = 14_000e18; // $14,000 borrow (70% LTV)

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.borrow(borrowAmount);
        vm.stopPrank();

        // Drop collateral price to make position unhealthy
        // Health factor = (collateral * threshold) / debt
        // At $1500: (10 * 1500 * 0.8) / 14000 = 0.857 < 1.0
        collateralPriceFeed.setPrice(1500e8);

        // Verify position is unhealthy
        uint256 hf = lendMachine.healthFactor(alice);
        assertLt(hf, 1e18);

        // Liquidate
        uint256 liquidateAmount = 7_000e18; // 50% of debt
        vm.prank(liquidator);
        lendMachine.liquidate(alice, liquidateAmount);

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.borrowedAmount, borrowAmount - liquidateAmount);
    }

    function test_liquidate_revertOnHealthyPosition() public {
        uint256 depositAmount = 10e18;
        uint256 borrowAmount = 5_000e18;

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.borrow(borrowAmount);
        vm.stopPrank();

        vm.prank(liquidator);
        vm.expectRevert("LendMachine: healthy position");
        lendMachine.liquidate(alice, 1_000e18);
    }

    // ============ Health Factor Tests ============

    function test_healthFactor_noDebt() public {
        vm.prank(alice);
        lendMachine.deposit(10e18);

        uint256 hf = lendMachine.healthFactor(alice);
        assertEq(hf, type(uint256).max);
    }

    function test_healthFactor_withDebt() public {
        uint256 depositAmount = 10e18; // $20,000
        uint256 borrowAmount = 10_000e18; // $10,000

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.borrow(borrowAmount);
        vm.stopPrank();

        // HF = (20000 * 0.8) / 10000 = 1.6
        uint256 hf = lendMachine.healthFactor(alice);
        assertEq(hf, 16e17); // 1.6e18
    }

    // ============ Interest Accrual Tests ============

    function test_interestAccrual() public {
        uint256 depositAmount = 10e18;
        uint256 borrowAmount = 10_000e18;

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.borrow(borrowAmount);
        vm.stopPrank();

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);

        // Trigger interest accrual by repaying
        vm.prank(alice);
        lendMachine.repay(1e18);

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        // Debt should have grown by ~5% (interest rate)
        // 10000 * 1.05 - 1 (repaid) = ~10499
        assertGt(position.borrowedAmount, borrowAmount - 1e18);
    }

    // ============ Admin Tests ============

    function test_pause() public {
        vm.prank(owner);
        lendMachine.pause();

        vm.prank(alice);
        vm.expectRevert();
        lendMachine.deposit(1e18);
    }

    function test_unpause() public {
        vm.startPrank(owner);
        lendMachine.pause();
        lendMachine.unpause();
        vm.stopPrank();

        vm.prank(alice);
        lendMachine.deposit(1e18);

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.collateralAmount, 1e18);
    }

    function test_setParameters() public {
        vm.prank(owner);
        lendMachine.setParameters(70e16, 75e16, 5e16);

        assertEq(lendMachine.ltv(), 70e16);
        assertEq(lendMachine.liquidationThreshold(), 75e16);
        assertEq(lendMachine.liquidationBonus(), 5e16);
    }

    // ============ View Function Tests ============

    function test_maxBorrowable() public {
        uint256 depositAmount = 10e18; // $20,000

        vm.prank(alice);
        lendMachine.deposit(depositAmount);

        // Max borrow at 75% LTV = $15,000
        uint256 maxBorrow = lendMachine.maxBorrowable(alice);
        assertEq(maxBorrow, 15_000e18);
    }

    function test_getPosition() public {
        uint256 depositAmount = 10e18;
        uint256 borrowAmount = 5_000e18;

        vm.startPrank(alice);
        lendMachine.deposit(depositAmount);
        lendMachine.borrow(borrowAmount);
        vm.stopPrank();

        ILendMachine.Position memory position = lendMachine.getPosition(alice);
        assertEq(position.collateralAmount, depositAmount);
        assertEq(position.borrowedAmount, borrowAmount);
    }
}
