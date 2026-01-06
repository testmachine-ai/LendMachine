// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {LendMachine} from "../src/LendMachine.sol";
import {LMToken} from "../src/LMToken.sol";
import {PriceOracle} from "../src/PriceOracle.sol";
import {RewardsDistributor} from "../src/RewardsDistributor.sol";

/**
 * @title Deploy
 * @notice Deployment script for the LendMachine protocol
 */
contract Deploy is Script {
    function run() external {
        // Load deployment private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load configuration from environment
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");
        address collateralPriceFeed = vm.envAddress("COLLATERAL_PRICE_FEED");
        address borrowPriceFeed = vm.envAddress("BORROW_PRICE_FEED");

        console.log("Deploying LendMachine Protocol...");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy LMToken
        LMToken lmToken = new LMToken(deployer);
        console.log("LMToken deployed at:", address(lmToken));

        // 2. Deploy PriceOracle
        PriceOracle priceOracle = new PriceOracle(deployer);
        console.log("PriceOracle deployed at:", address(priceOracle));

        // 3. Configure price feeds
        priceOracle.setPriceFeed(collateralToken, collateralPriceFeed);
        priceOracle.setPriceFeed(address(lmToken), borrowPriceFeed);
        console.log("Price feeds configured");

        // 4. Deploy LendMachine
        LendMachine lendMachine = new LendMachine(
            collateralToken,
            address(lmToken),
            address(priceOracle),
            deployer
        );
        console.log("LendMachine deployed at:", address(lendMachine));

        // 5. Deploy RewardsDistributor
        RewardsDistributor rewardsDistributor = new RewardsDistributor(
            address(lmToken),
            deployer
        );
        console.log("RewardsDistributor deployed at:", address(rewardsDistributor));

        // 6. Configure integrations
        rewardsDistributor.setLendMachine(address(lendMachine));
        lendMachine.setRewardsDistributor(address(rewardsDistributor));
        console.log("Integrations configured");

        // 7. Setup minter role for LendMachine
        lmToken.setMinter(address(lendMachine), true);
        console.log("Minter role granted to LendMachine");

        // 8. Transfer initial liquidity to LendMachine
        uint256 initialLiquidity = 5_000_000e18;
        lmToken.transfer(address(lendMachine), initialLiquidity);
        console.log("Initial liquidity transferred:", initialLiquidity);

        // 9. Transfer rewards to RewardsDistributor
        uint256 rewardsAllocation = 1_000_000e18;
        lmToken.transfer(address(rewardsDistributor), rewardsAllocation);
        console.log("Rewards allocation transferred:", rewardsAllocation);

        vm.stopBroadcast();

        // Log deployment summary
        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("LMToken:", address(lmToken));
        console.log("PriceOracle:", address(priceOracle));
        console.log("LendMachine:", address(lendMachine));
        console.log("RewardsDistributor:", address(rewardsDistributor));
        console.log("==========================");
    }
}

/**
 * @title DeployLocal
 * @notice Deployment script for local testing with mock tokens
 */
contract DeployLocal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying LendMachine Protocol (Local)...");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy LMToken
        LMToken lmToken = new LMToken(deployer);

        // Deploy PriceOracle (will need manual price feed setup)
        PriceOracle priceOracle = new PriceOracle(deployer);

        // For local testing, we'd need to deploy mock tokens and price feeds
        // This script assumes they'll be set up separately or via tests

        console.log("LMToken deployed at:", address(lmToken));
        console.log("PriceOracle deployed at:", address(priceOracle));

        vm.stopBroadcast();
    }
}
