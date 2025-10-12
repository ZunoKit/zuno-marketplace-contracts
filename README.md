# Zuno Marketplace Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.30-blue.svg)](https://docs.soliditylang.org/)
[![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen.svg)](#testing)

A production-ready, modular NFT marketplace smart contract system built with Foundry. Supports ERC721 & ERC1155 tokens with advanced trading features including auctions, offers, bundles, and comprehensive collection management.

## ✨ Features

- **Multi-token Support**: ERC721 and ERC1155 collections
- **Advanced Trading**: Direct sales, auctions, offers, and bundles
- **Collection Management**: Factory pattern for creating collections
- **Fee System**: Configurable marketplace and royalty fees
- **Access Control**: Role-based permissions and emergency controls
- **Clean Architecture**: Modular, organized, and maintainable code

## 🏗️ Architecture

### Smart Contracts (17 Core Contracts)

#### Collections (4)

- `ERC721Collection` / `ERC1155Collection` - NFT collections
- `ERC721CollectionFactory` / `ERC1155CollectionFactory` - Collection creation

#### Exchange (3)

- `ERC721NFTExchange` / `ERC1155NFTExchange` - Trading logic
- `NFTExchangeRegistry` - Exchange management

#### Marketplace (3)

- `AdvancedListingManager` - Complex listing logic
- `OfferManager` - Offer system
- `BundleManager` - Bundle trading

#### Management (3)

- `AdvancedFeeManager` - Fee management
- `AdvancedRoyaltyManager` - Royalty system
- `EmergencyManager` - Emergency controls

#### Access & Validation (4)

- `MarketplaceAccessControl` - Role-based access
- `CollectionVerifier` - Collection validation
- `ListingValidator` - Listing validation
- `ListingHistoryTracker` - History tracking

### Frontend

Clean React architecture with:

- **Modular Contracts**: Organized ABIs, addresses, and configs
- **MetaMask Integration**: Web3 wallet connectivity
- **Redux State Management**: Centralized state
- **Responsive Design**: Mobile-friendly interface

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- [Node.js](https://nodejs.org/) (v18+) and [pnpm](https://pnpm.io/)
- Git

### Installation

```bash
# Clone the repository
https://github.com/ZunoKit/zuno-marketplace-contracts.git
cd zuno-marketplace-contracts

# Install dependencies
forge install
pnpm install

# Build contracts
pnpm build
```

### Local Development

```bash
# 1. Start local blockchain
make start-anvil
# OR: anvil --port 8545

# 2. Deploy contracts to local network
make deploy-all-local

# 3. Run tests
pnpm test

# 4. Format code
pnpm format
```

---

## 📁 Project Structure

```
zuno-marketplace-contracts/
├── src/contracts/
│   ├── core/                # Core marketplace contracts
│   │   ├── collection/      # ERC721/ERC1155 collections
│   │   ├── exchange/        # Trading logic
│   │   ├── auction/         # Auction mechanisms
│   │   ├── fees/           # Fee & royalty management
│   │   ├── access/         # Access control
│   │   └── validation/     # Input validation
│   ├── libraries/          # Utility libraries
│   ├── interfaces/         # Contract interfaces
│   ├── events/            # Event definitions
│   └── errors/            # Custom errors
├── script/                # Deployment scripts
├── test/                  # Comprehensive test suite
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── mocks/           # Mock contracts
├── lib/                  # Dependencies (git submodules)
└── foundry.toml         # Foundry configuration
```

## 🧪 Testing

The project includes comprehensive test coverage with unit, integration, and end-to-end tests.

```bash
# Run all tests
pnpm test

# Run tests with verbosity for debugging
pnpm test:verbose

# Run specific test files
forge test --match-path test/unit/collection/unit/UnitERC721CollectionTest.t.sol

# Run tests matching pattern
forge test --match-test testCreateCollection

# Run tests with gas reporting
forge test --gas-report

# Coverage report
forge coverage
```

### Test Categories

- **Unit Tests**: Individual contract functionality (`test/unit/`)
- **Integration Tests**: Cross-contract interactions (`test/integration/`)
- **End-to-End Tests**: Complete workflows
- **Stress Tests**: High-load scenarios
- **Mock Tests**: Using mock contracts for isolation

## 🔧 Configuration

### Network Configuration

Configure networks in `foundry.toml`:

```toml
[rpc_endpoints]
localhost = "http://localhost:8545"
anvil = "http://127.0.0.1:8545"
sepolia = "https://rpc.sepolia.org"
mainnet = "https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY"
```

### Environment Variables

Create a `.env` file for deployment:

```bash
# Deployment
MARKETPLACE_WALLET=0x...
PRIVATE_KEY=0x...

# RPC URLs (optional, can use foundry.toml)
SEPOLIA_RPC_URL=https://...
MAINNET_RPC_URL=https://...

```

### Available Scripts

```bash
# Development
pnpm build           # Compile contracts
pnpm test           # Run tests
pnpm format         # Format Solidity code
pnpm format:check   # Check formatting

# Deployment
make start-anvil         # Start local blockchain
make deploy-all-local    # Deploy to local network
```

## 🎯 Usage

### Contract Deployment

```bash
# Deploy to testnet (Sepolia)
forge script script/DeployExchanges.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Deploy to mainnet
forge script script/DeployExchanges.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

### Integration Examples

```solidity
// Create ERC721 Collection
ERC721CollectionFactory factory = ERC721CollectionFactory(FACTORY_ADDRESS);
address collection = factory.createCollection(
    "My NFT Collection",
    "MNC",
    "ipfs://base-uri/",
    1000,  // max supply
    msg.sender  // owner
);

// List NFT for sale
ERC721NFTExchange exchange = ERC721NFTExchange(EXCHANGE_ADDRESS);
exchange.createListing(
    collection,
    tokenId,
    price,
    duration,
    paymentToken
);
```

### Frontend Integration (MarketplaceHub)

The frontend only needs the `MarketplaceHub` address. Initialize once, cache addresses, and call core
contracts directly. See detailed guide in `docs/user-guide.md`.

```typescript
// config.ts
export const MARKETPLACE_HUB = "0x...";

// Initialize Hub and cache addresses
import { ethers, Contract } from "ethers";
import MarketplaceHubABI from "./abis/MarketplaceHub.json";

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const hub = new Contract(MARKETPLACE_HUB, MarketplaceHubABI, provider);

// Get all addresses once
const addresses = await hub.getAllAddresses();

// Auto-detect exchange for an NFT and list directly on the exchange
const exchangeAddr = await hub.getExchangeFor(nftAddress);
const exchange = new Contract(exchangeAddr, ExchangeABI, signer);
await exchange.listNFT(nftAddress, tokenId, ethers.parseEther("1.0"), 86400);

// Helper: calculate fees
const fees = await hub.calculateFees(
  nftAddress,
  tokenId,
  ethers.parseEther("1.0")
);
```

More examples (React hook, end-to-end flows) in `docs/user-guide.md`.

### Core Features

- **🏭 Collection Factory**: Deploy new ERC721/ERC1155 collections
- **💰 Direct Trading**: Fixed-price sales with instant settlement
- **🏛️ Auction System**: English & Dutch auctions
- **💡 Offer System**: Make offers on any NFT
- **📦 Bundle Trading**: Trade multiple NFTs together
- **💎 Royalty Support**: EIP-2981 compliant royalty distribution

## 🔒 Security

The smart contracts implement multiple security layers:

### Access Control

- **Role-based Permissions**: Admin, operator, and user roles
- **Emergency Controls**: Pause/unpause functionality for critical operations
- **Ownership Management**: Secure ownership transfer mechanisms

### Attack Prevention

- **Reentrancy Guards**: Protection against reentrancy attacks
- **Input Validation**: Comprehensive parameter validation
- **Safe Math**: Built-in overflow/underflow protection (Solidity ^0.8.0)
- **Pull Payment Pattern**: Secure fund withdrawal mechanisms

### Code Quality

- **Comprehensive Testing**: >90% test coverage
- **Gas Optimization**: Efficient contract design
- **Upgradeable Patterns**: Future-proof architecture
- **Static Analysis**: Automated security scanning

### Audit Status

⚠️ **This code has not been audited yet. Do not use in production without a professional security audit.**

## 📊 Gas Optimization

| Contract           | Deployment Cost | Avg. Function Cost |
| ------------------ | --------------- | ------------------ |
| ERC721NFTExchange  | ~2.1M gas       | ~150k gas          |
| ERC1155NFTExchange | ~2.0M gas       | ~140k gas          |
| Collection Factory | ~1.8M gas       | ~200k gas          |

_Gas costs are approximate and may vary based on network conditions_

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Development Process

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Write** tests for your changes
4. **Ensure** all tests pass (`pnpm test`)
5. **Format** your code (`pnpm format`)
6. **Commit** with conventional commit format (`feat: add amazing feature`)
7. **Push** to your branch (`git push origin feature/amazing-feature`)
8. **Open** a Pull Request

### Commit Message Format

This project uses [Conventional Commits](https://conventionalcommits.org/):

```
type(scope): description

feat(marketplace): add bundle trading functionality
fix(auction): resolve reentrancy vulnerability
docs(readme): update installation instructions
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `contract`, `deploy`, `security`

### Pull Request Guidelines

- Include tests for any new functionality
- Update documentation as needed
- Ensure CI passes (tests, formatting, linting)
- Link to relevant issues
- Provide clear description of changes

### Development Environment

The project uses:

- **Husky** for Git hooks
- **Commitlint** for commit message validation
- **Foundry** for smart contract development
- **pnpm** for package management

## 📚 Documentation

### Contract Addresses

| Network | Contract           | Address |
| ------- | ------------------ | ------- |
| Sepolia | ERC721NFTExchange  | `TBD`   |
| Sepolia | ERC1155NFTExchange | `TBD`   |
| Mainnet | ERC721NFTExchange  | `TBD`   |
| Mainnet | ERC1155NFTExchange | `TBD`   |

### API Reference

For detailed API documentation, see:

- [Contract Interfaces](./src/contracts/interfaces/)
- [Events](./src/contracts/events/)
- [Custom Errors](./src/contracts/errors/)

### Further Reading

- [Foundry Documentation](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [EIP-721: NFT Standard](https://eips.ethereum.org/EIPS/eip-721)
- [EIP-1155: Multi Token Standard](https://eips.ethereum.org/EIPS/eip-1155)
- [EIP-2981: Royalty Standard](https://eips.ethereum.org/EIPS/eip-2981)

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/your-org/zuno-marketplace-contracts/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/zuno-marketplace-contracts/discussions)
- **Security**: For security issues, please email security@yourorg.com

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**⚠️ Disclaimer**: This software is provided "as is", without warranty of any kind. Use at your own risk. Always conduct thorough testing and security audits before deploying to production.
