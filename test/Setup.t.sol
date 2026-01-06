// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {LendMachine} from "../src/LendMachine.sol";
import {LMToken} from "../src/LMToken.sol";
import {PriceOracle} from "../src/PriceOracle.sol";
import {RewardsDistributor} from "../src/RewardsDistributor.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPriceFeed} from "./mocks/MockPriceFeed.sol";

/**
 * @title Setup
 * @notice Base test setup for LendMachine tests
 */
contract Setup is Test {
    // Contracts
    LendMachine public lendMachine;
    LMToken public lmToken;
    PriceOracle public priceOracle;
    RewardsDistributor public rewardsDistributor;
    MockERC20 public collateralToken;
    MockPriceFeed public collateralPriceFeed;
    MockPriceFeed public borrowPriceFeed;

    // Actors
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public liquidator = makeAddr("liquidator");

    // Constants
    uint256 public constant INITIAL_COLLATERAL_PRICE = 2000e8; // $2000
    uint256 public constant INITIAL_BORROW_PRICE = 1e8; // $1
    uint256 public constant INITIAL_BALANCE = 1_000_000e18;

    function setUp() public virtual {
        vm.startPrank(owner);

        // Deploy collateral token (e.g., WETH-like)
        collateralToken = new MockERC20("Wrapped Ether", "WETH", 18);

        // Deploy LMToken (borrow token)
        lmToken = new LMToken(owner);

        // Deploy mock price feeds
        collateralPriceFeed = new MockPriceFeed(int256(INITIAL_COLLATERAL_PRICE), 8);
        borrowPriceFeed = new MockPriceFeed(int256(INITIAL_BORROW_PRICE), 8);

        // Deploy price oracle
        priceOracle = new PriceOracle(owner);
        priceOracle.setPriceFeed(address(collateralToken), address(collateralPriceFeed));
        priceOracle.setPriceFeed(address(lmToken), address(borrowPriceFeed));

        // Deploy LendMachine
        lendMachine = new LendMachine(
            address(collateralToken),
            address(lmToken),
            address(priceOracle),
            owner
        );

        // Deploy rewards distributor
        rewardsDistributor = new RewardsDistributor(address(lmToken), owner);
        rewardsDistributor.setLendMachine(address(lendMachine));
        lendMachine.setRewardsDistributor(address(rewardsDistributor));

        // Setup minter roles
        lmToken.setMinter(address(lendMachine), true);

        // Transfer borrow tokens to LendMachine for liquidity
        lmToken.transfer(address(lendMachine), 5_000_000e18);

        // Fund rewards distributor
        lmToken.transfer(address(rewardsDistributor), 1_000_000e18);

        vm.stopPrank();

        // Fund test accounts with collateral
        collateralToken.mint(alice, INITIAL_BALANCE);
        collateralToken.mint(bob, INITIAL_BALANCE);
        collateralToken.mint(liquidator, INITIAL_BALANCE);

        // Fund test accounts with borrow tokens (for repayment)
        vm.prank(owner);
        lmToken.transfer(alice, 100_000e18);
        vm.prank(owner);
        lmToken.transfer(bob, 100_000e18);
        vm.prank(owner);
        lmToken.transfer(liquidator, 1_000_000e18);

        // Approve LendMachine to spend tokens
        vm.prank(alice);
        collateralToken.approve(address(lendMachine), type(uint256).max);
        vm.prank(alice);
        lmToken.approve(address(lendMachine), type(uint256).max);

        vm.prank(bob);
        collateralToken.approve(address(lendMachine), type(uint256).max);
        vm.prank(bob);
        lmToken.approve(address(lendMachine), type(uint256).max);

        vm.prank(liquidator);
        collateralToken.approve(address(lendMachine), type(uint256).max);
        vm.prank(liquidator);
        lmToken.approve(address(lendMachine), type(uint256).max);
    }
}
