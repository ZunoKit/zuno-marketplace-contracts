# Zuno Marketplace Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.30-blue.svg)](https://docs.soliditylang.org/)
[![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen.svg)](#testing)

A production-ready, modular NFT marketplace smart contract system built with Foundry. Supports ERC721 & ERC1155 tokens with advanced trading features including auctions, offers, bundles, and comprehensive collection management with a unified Hub architecture for simplified frontend integration.

## ✨ Features

- **Multi-token Support**: ERC721 and ERC1155 collections with automatic standard detection
- **Advanced Trading**: Direct sales, English/Dutch auctions, offers, and bundle trading
- **Hub Architecture**: Single entry point (MarketplaceHub) for all frontend interactions
- **Collection Management**: Factory pattern with proxy deployments for gas-efficient collection creation
- **Fee System**: Configurable marketplace fees and EIP-2981 royalty support
- **Access Control**: Role-based permissions, timelock protection, and emergency controls
- **Clean Architecture**: Modular contracts with separated concerns and type-safe operations
- **Gas Optimized**: Minimal proxy pattern, efficient storage packing, and batch operations

## 🏗️ Architecture

### Smart Contract Architecture

#### Core Contracts

**Hub & Registries**
- `MarketplaceHub` - Single entry point for frontend, provides address discovery
- `ExchangeRegistry` - Maps token standards to exchange contracts
- `CollectionRegistry` - Maps token types to factory contracts
- `FeeRegistry` - Unified fee calculations across platform
- `AuctionRegistry` - Maps auction types to implementation contracts

**Exchange Layer**
- `BaseNFTExchange` - Abstract base with common trading logic
- `ERC721NFTExchange` / `ERC1155NFTExchange` - Token-specific implementations
- `NFTExchangeFactory` - Creates exchange instances
- `NFTExchangeRegistry` - Manages exchange instances

**Collection System**
- `ERC721Collection` / `ERC1155Collection` - NFT collection contracts
- `ERC721CollectionFactory` / `ERC1155CollectionFactory` - Gas-efficient collection deployment
- `ERC721CollectionImplementation` / `ERC1155CollectionImplementation` - Proxy implementations
- `CollectionVerifier` - Collection verification and validation

**Auction System**
- `BaseAuction` - Common auction logic
- `EnglishAuction` / `DutchAuction` - Auction type implementations
- `EnglishAuctionImplementation` / `DutchAuctionImplementation` - Proxy implementations
- `AuctionFactory` - Creates auction instances with minimal proxy pattern

**Trading Features**
- `AdvancedListingManager` - Orchestrates complex listing types
- `OfferManager` - NFT and collection offer management
- `BundleManager` - Multi-NFT bundle trading

**Fee & Royalty Management**
- `BaseFee` - Core fee calculations
- `AdvancedFeeManager` - Marketplace fee configuration
- `AdvancedRoyaltyManager` - EIP-2981 royalty distribution

**Security & Access Control**
- `MarketplaceAccessControl` - Role-based permissions (Admin, Operator, User)
- `EmergencyManager` - Emergency pause/unpause functionality
- `MarketplaceTimelock` - 48-hour delay for critical operations
- `ListingValidator` - Input validation and sanity checks

**Analytics & History**
- `ListingHistoryTracker` - Transaction history and analytics

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
├── src/
│   ├── core/                 # Core marketplace contracts
│   │   ├── auction/          # English & Dutch auction implementations
│   │   ├── bundles/          # Bundle trading functionality
│   │   ├── collection/       # Collection verification & management
│   │   ├── exchange/         # ERC721/ERC1155 exchange contracts
│   │   ├── factory/          # Factory contracts for collections & auctions
│   │   ├── fees/             # Fee & royalty management
│   │   ├── listing/          # Advanced listing management
│   │   ├── offers/           # Offer system
│   │   ├── proxy/            # Proxy implementations for gas efficiency
│   │   ├── security/         # Emergency & timelock controls
│   │   ├── access/           # Role-based access control
│   │   ├── analytics/        # History tracking & analytics
│   │   └── validation/       # Input validation & verification
│   ├── router/               # MarketplaceHub entry point
│   ├── registry/             # Registry contracts for mappings
│   ├── common/               # Base contracts & shared logic
│   ├── libraries/            # Reusable utility libraries
│   ├── interfaces/           # Contract interfaces
│   ├── types/                # Type definitions & structs
│   ├── events/               # Event definitions
│   └── errors/               # Custom error definitions
├── script/
│   └── deploy/               # Deployment scripts
│       └── DeployAll.s.sol   # Complete deployment script
├── test/
│   ├── unit/                 # Unit tests for each contract
│   ├── integration/          # Cross-contract integration tests
│   ├── e2e/                  # End-to-end workflow tests
│   ├── gas/                  # Gas optimization tests
│   ├── deploy/               # Deployment tests
│   └── utils/                # Test helpers & utilities
├── docs/                     # Documentation
│   ├── user-guide.md         # Frontend integration guide
│   ├── architecture/         # Architecture documentation
│   ├── api/                  # API documentation
│   └── security/             # Security documentation
├── lib/                      # External dependencies (git submodules)
├── .cursor/rules/            # Cursor AI development rules
├── foundry.toml              # Foundry configuration
├── Makefile                  # Build & deployment shortcuts
└── CLAUDE.md                 # Claude AI assistant guidelines
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
# Deploy EVERYTHING with one command (recommended)
forge script script/deploy/DeployAll.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Output shows MarketplaceHub address - that's the ONLY address frontend needs!

# Alternative: Deploy to mainnet
forge script script/deploy/DeployAll.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --verify
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

The frontend only needs the `MarketplaceHub` address - everything else is discoverable through it.

```typescript
// config.ts
export const MARKETPLACE_HUB = "0x..."; // ONLY address needed

// Initialize Hub
import { ethers, Contract } from "ethers";
import MarketplaceHubABI from "./abis/MarketplaceHub.json";

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const hub = new Contract(MARKETPLACE_HUB, MarketplaceHubABI, provider);

// Get all contract addresses (cache these)
const {
  erc721Exchange,
  erc1155Exchange,
  erc721Factory,
  erc1155Factory,
  englishAuction,
  dutchAuction,
  auctionFactory,
  feeRegistry,
  bundleManager,
  offerManager
} = await hub.getAllAddresses();

// Auto-detect exchange for any NFT
const exchangeAddr = await hub.getExchangeFor(nftAddress);
const exchange = new Contract(exchangeAddr, ExchangeABI, signer);

// List NFT with automatic exchange selection
await exchange.listNFT(nftAddress, tokenId, ethers.parseEther("1.0"), 86400);

// Calculate fees before purchase
const fees = await hub.calculateFees(nftAddress, tokenId, salePrice);
console.log(`Total price: ${fees.totalPrice}, Platform fee: ${fees.platformFee}`);

// Verify collection before interaction
const { isValid, tokenType } = await hub.verifyCollection(collectionAddress);
```

See comprehensive guide with React hooks, TypeScript types, and feature examples in `docs/user-guide.md` and `FE-GUIDE.md`.

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
