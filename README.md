# LendMachine Protocol

A decentralized lending protocol enabling overcollateralized borrowing on EVM-compatible blockchains.

## Overview

LendMachine allows users to deposit collateral assets and borrow against them at competitive rates. The protocol features automated interest accrual, liquidation mechanisms, and an integrated rewards system for depositors.

## Features

- **Overcollateralized Lending**: Deposit collateral and borrow up to 75% of its value
- **Dynamic Interest Rates**: Configurable interest rates with automatic accrual
- **Liquidation Protection**: Health factor monitoring with liquidation at 80% threshold
- **Rewards System**: Earn bonus rewards on deposited collateral
- **Price Oracle Integration**: Chainlink-compatible price feeds for accurate valuations

## Architecture

```
src/
├── LendMachine.sol          # Core lending pool contract
├── LMToken.sol              # Protocol native token (LMT)
├── PriceOracle.sol          # Price feed aggregator
├── RewardsDistributor.sol   # Depositor rewards system
└── interfaces/
    ├── ILendMachine.sol
    ├── IPriceOracle.sol
    └── IRewardsDistributor.sol
```

## Protocol Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| LTV Ratio | 75% | Maximum loan-to-value ratio |
| Liquidation Threshold | 80% | Health factor threshold for liquidation |
| Liquidation Bonus | 10% | Bonus collateral awarded to liquidators |
| Interest Rate | 5% APR | Annual interest rate on borrowed funds |

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js >= 16 (optional, for additional tooling)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd lendmachine

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

### Local Development

```bash
# Start local node
anvil

# Deploy to local node
forge script script/Deploy.s.sol:DeployLocal --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment

Create a `.env` file with the following variables:

```env
PRIVATE_KEY=your_private_key
COLLATERAL_TOKEN=0x...
COLLATERAL_PRICE_FEED=0x...
BORROW_PRICE_FEED=0x...
```

Then deploy:

```bash
source .env
forge script script/Deploy.s.sol:Deploy --rpc-url <RPC_URL> --broadcast --verify
```

## Usage

### Depositing Collateral

```solidity
// Approve collateral token
collateralToken.approve(address(lendMachine), amount);

// Deposit collateral
lendMachine.deposit(amount);
```

### Borrowing

```solidity
// Check maximum borrowable amount
uint256 maxBorrow = lendMachine.maxBorrowable(msg.sender);

// Borrow tokens
lendMachine.borrow(borrowAmount);
```

### Repaying

```solidity
// Approve borrow token
borrowToken.approve(address(lendMachine), amount);

// Repay debt
lendMachine.repay(amount);
```

### Withdrawing Collateral

```solidity
// Withdraw collateral (must maintain healthy position)
lendMachine.withdraw(amount);
```

### Liquidating Positions

```solidity
// Check if position is liquidatable
uint256 healthFactor = lendMachine.healthFactor(user);
require(healthFactor < 1e18, "Position is healthy");

// Liquidate up to 50% of debt
lendMachine.liquidate(user, debtAmount);
```

## Testing

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test
forge test --match-test test_deposit

# Generate coverage report
forge coverage
```

## Security

This protocol is currently undergoing security review prior to mainnet deployment.

If you discover a security vulnerability, please report it to: security@lendmachine.xyz

### Audit Status

- [ ] Internal review
- [ ] External audit
- [ ] Bug bounty program

## Contract Addresses

### Mainnet

*Not yet deployed*

### Sepolia Testnet

*Not yet deployed*

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.

## Disclaimer

This software is provided "as is" without warranty of any kind. Use at your own risk. Always perform your own security review before interacting with any smart contract.
