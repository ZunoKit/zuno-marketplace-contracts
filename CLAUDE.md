# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zuno Marketplace is a production-ready, modular NFT marketplace built with Foundry/Solidity ^0.8.30. It supports ERC721 and ERC1155 tokens with advanced trading features including auctions, offers, bundles, and comprehensive collection management.

**Tech Stack:**

- Foundry for smart contract development, testing, and deployment
- OpenZeppelin contracts for security and standards
- Solidity ^0.8.30
- Makefile for common tasks

**Note:** This is a pure Foundry project. Despite the README mentioning pnpm, there is no package.json - use Foundry or Makefile commands instead.

## Common Commands

### Building and Testing

```bash
# Build contracts
forge build
# OR
make build

# Run all tests
forge test
# OR
make test

# Run tests with varying verbosity
forge test -vv          # Show test names and failures
forge test -vvv         # Also show stack traces
forge test -vvvv        # Show full execution traces
# OR via Makefile
make test-v
make test-vvv

# Run specific test file
forge test --match-path test/unit/collection/unit/UnitERC721CollectionTest.t.sol
# OR via Makefile
make test-file FILE=test/unit/collection/unit/UnitERC721CollectionTest.t.sol

# Run tests matching a pattern
forge test --match-test testCreateCollection
# OR via Makefile
make test-match PATTERN=testCreateCollection

# Run tests with gas reporting
forge test --gas-report

# Generate coverage report
forge coverage
# OR
make coverage

# Generate gas snapshots
forge snapshot
# OR
make snapshot

# Format Solidity code
forge fmt
# OR
make format

# Clean build artifacts
forge clean
# OR
make clean
```

### Local Development

```bash
# Start local Anvil blockchain (port 8545)
anvil --port 8545
# OR
make start-anvil

# Deploy all contracts to local network
make deploy-all-local

# Deploy only exchanges
make deploy-exchanges

# Deploy only collections
make deploy-collections
```

### Deployment (Network)

```bash
# Deploy EVERYTHING (core + hub) in one command
forge script script/deploy/DeployAll.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Output will show MarketplaceHub address - that's the ONLY address frontend needs!
```

## Architecture Overview

### Core Design Patterns

**1. Proxy Pattern for Gas Efficiency:**

- Collection factories use minimal proxy (clone) pattern via OpenZeppelin's `Clones.sol`
- Implementation contracts: `ERC721CollectionImplementation`, `ERC1155CollectionImplementation`, `EnglishAuctionImplementation`, `DutchAuctionImplementation`
- Factories deploy cheap clones that delegate to implementation contracts
- Reduces deployment gas costs significantly

**2. Initializer Pattern:**

- Base contracts like `BaseNFTExchange` use OpenZeppelin's `Initializable`
- Contracts have empty constructors and separate `initialize()` functions
- Enables proxy pattern compatibility and upgradeable designs

**3. Modular Architecture:**

- Core functionality split across specialized contracts (Exchange, Collection, Auction, Fees, Access)
- Libraries handle reusable logic (NFTTransferLib, PaymentDistributionLib, RoyaltyLib, etc.)
- Separate files for Events, Errors, Types/Structs
- **Registry + Hub Pattern** for frontend integration (see below)

**4. Registry + Hub Pattern (NEW - Simplified Frontend Integration):**

- **MarketplaceHub**: Single entry point contract that provides address discovery
- **Registries**: ExchangeRegistry, CollectionRegistry, FeeRegistry, AuctionRegistry
- **Philosophy**: Hub does NOT wrap function calls, only provides contract addresses
- **Benefits**: Minimal gas overhead, easy maintenance, direct contract calls from frontend
- See `docs/user-guide.md` for details

**5. Role-Based Access Control:**

- `MarketplaceAccessControl` manages admin, operator, and user permissions
- `EmergencyManager` provides pause/unpause functionality for critical scenarios
- `MarketplaceTimelock` enforces 48-hour delay on critical parameter changes to prevent rug pulls

### Hub + Registry Architecture

**MarketplaceHub (src/router/MarketplaceHub.sol):**

- Single contract address for frontend integration
- Provides `getAllAddresses()` to get all contract addresses in one call
- Provides `getExchangeFor(nftContract)` to auto-detect ERC721 vs ERC1155
- Helper functions: `calculateFees()`, `verifyCollection()`, etc.
- **Does NOT wrap function calls** - only provides addresses and queries

**Registries (src/registry/):**

- `ExchangeRegistry` - Maps token standards to exchange contracts
- `CollectionRegistry` - Maps token types to factory contracts
- `FeeRegistry` - Unified fee calculations across platform
- `AuctionRegistry` - Maps auction types to auction contracts

**Frontend Flow:**

1. Initialize with MarketplaceHub address only
2. Call `hub.getAllAddresses()` to get all contract addresses
3. Create contract instances for each address
4. Call contracts directly (not through hub)

See `docs/user-guide.md` for complete documentation.

### Hub + Registry Quick Start

1. Frontend needs only the `MarketplaceHub` address
2. Call `hub.getAllAddresses()` once and cache returned contract addresses
3. Auto-detect exchange via `hub.getExchangeFor(nftContract)` and call the exchange directly
4. Use Hub helpers for queries only: `calculateFees(...)`, `verifyCollection(...)`

#### Add a new token standard or module

- Extend the relevant enum/interface in the registry
- Deploy the new contract (e.g., exchange/auction)
- Register its address in the corresponding registry (admin-only)
- Frontend remains unchanged; Hub queries reflect the new registration

### Key Contract Relationships

**Exchange Layer:**

- `BaseNFTExchange` - Abstract base with common listing/trading logic
- `ERC721NFTExchange` & `ERC1155NFTExchange` - Token-specific implementations
- `NFTExchangeRegistry` - Tracks and manages exchange instances
- `AdvancedListingManager` - Handles complex listing types (auctions, bundles, offers)

**Collection Layer:**

- `BaseCollection` - Common NFT collection functionality
- `ERC721Collection` & `ERC1155Collection` - Standard collections
- `ERC721CollectionImplementation` & `ERC1155CollectionImplementation` - Proxy implementations
- `ERC721CollectionFactory` & `ERC1155CollectionFactory` - Deploy new collections via clones
- `CollectionFactoryRegistry` - Centralized factory management
- `CollectionVerifier` - Validates collection addresses

**Auction Layer:**

- `BaseAuction` - Common auction logic
- `EnglishAuction` & `DutchAuction` - Auction types
- `AuctionFactory` - Creates auction instances

**Trading Features:**

- `OfferManager` - Handle offer-based trading
- `BundleManager` - Multi-NFT bundle sales
- `AdvancedListingManager` - Orchestrates advanced trading types

**Management Layer:**

- `AdvancedFeeManager` - Marketplace fee configuration
- `AdvancedRoyaltyManager` - EIP-2981 royalty handling
- `ListingValidator` - Input validation for listings
- `ListingHistoryTracker` - Track listing history and analytics

**Security Layer:**

- `MarketplaceAccessControl` - Role-based permissions
- `EmergencyManager` - Emergency pause controls
- `MarketplaceTimelock` - 48-hour timelock for critical admin actions
- All core contracts use ReentrancyGuard and input validation

### Data Structures

Key types defined in `src/types/ListingTypes.sol`:

- `Listing` - Core listing data structure
- `ListingType` enum - FIXED_PRICE, AUCTION, DUTCH_AUCTION, BUNDLE, OFFER_BASED, etc.
- `ListingStatus` enum - ACTIVE, SOLD, CANCELLED, EXPIRED, PAUSED, PENDING
- `AuctionParams` - English auction parameters
- `DutchAuctionParams` - Dutch auction parameters
- `Offer` - Offer data structure
- `Bundle` - Bundle trading data
- `CollectionParams` - Collection creation parameters

### Libraries

Reusable logic organized in `src/libraries/`:

- `NFTTransferLib` - Safe NFT transfers (ERC721/ERC1155)
- `PaymentDistributionLib` - Payment splitting logic
- `RoyaltyLib` - EIP-2981 royalty calculations
- `NFTValidationLib` - NFT ownership and approval validation
- `BatchOperationsLib` - Batch operations handling
- `AuctionUtilsLib` - Auction-specific utilities
- `BidManagementLib` - Bid management logic
- `ArrayUtilsLib` - Array manipulation utilities

### Events and Errors

**Events:** Organized in `src/events/` by contract domain:

- `NFTExchangeEvents.sol` - Exchange events
- `CollectionEvents.sol` - Collection events
- `AuctionEvents.sol` - Auction events
- `FeeEvents.sol` - Fee-related events
- `AdvancedListingEvents.sol` - Advanced listing events

**Errors:** Custom errors in `src/errors/` for gas efficiency:

- `NFTExchangeErrors.sol`
- `CollectionErrors.sol`
- `AuctionErrors.sol`
- `FeeErrors.sol`
- `AdvancedListingErrors.sol`

## Testing Structure

Tests organized by type in `test/`:

**Unit Tests** (`test/unit/`):

- `collection/` - Collection factory and NFT contract tests
- `exchange/` - Exchange contract tests
- `auction/` - Auction mechanism tests
- `access/` - Access control tests
- `analytics/` - History tracking tests
- `fees/` - Fee management tests
- `security/` - Emergency and timelock tests
- `validation/` - Validator tests

**Integration Tests** (`test/integration/`):

- End-to-end workflows
- Cross-contract interactions
- Complete trading scenarios
- Stress tests

**Mock Contracts** (`test/mocks/`):

- Used for isolated unit testing

## Important Patterns and Conventions

### Fee System

- Taker fee: 2% (200 basis points) - configurable via `s_takerFee`
- Basis points denominator: 10000 (BPS_DENOMINATOR)
- Royalty support via EIP-2981
- Fee distribution handled by `PaymentDistributionLib`

### Listing IDs

Listings use deterministic `bytes32` IDs generated from:

```solidity
keccak256(abi.encodePacked(contractAddress, tokenId, seller, block.timestamp))
```

### Security Considerations

- All state-changing functions use ReentrancyGuard
- Input validation via dedicated validator contracts
- Timelock protection for critical parameter changes (48 hours)
- Emergency pause functionality for critical scenarios
- Pull payment pattern for fund withdrawals
- Comprehensive ownership and approval checks before NFT transfers

### Gas Optimization

- Use minimal proxy pattern for collection/auction deployment
- Libraries for code reuse instead of inheritance where appropriate
- Custom errors instead of string reverts
- Efficient storage patterns and packing

### Initialization vs. Constructors

When working with proxy-compatible contracts:

- Constructors should be minimal or empty
- Use `initialize()` functions with `initializer` modifier
- Call parent initializers using `__ParentContract_init()` pattern

## Foundry.toml

Don't use `via_ir = true`

## Environment Variables

Create `.env` for deployment (not tracked in git):

```bash
MARKETPLACE_WALLET=0x...  # Admin address
PRIVATE_KEY=0x...          # Deployer private key
SEPOLIA_RPC_URL=https://...
MAINNET_RPC_URL=https://...
```

That's it! No other addresses needed. DeployAll.s.sol deploys everything.

## Deployment Scripts

Located in `script/deploy/`:

- **`DeployAll.s.sol`** - Deploy EVERYTHING (core + hub) in one command

Usage:
```bash
forge script script/deploy/DeployAll.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

Output:
- All core contracts deployed
- MarketplaceHub deployed and configured
- **Frontend only needs MarketplaceHub address** (shown at end of deployment)

## Commit Convention

Project uses Conventional Commits:

```
type(scope): description

Types: feat, fix, docs, style, refactor, test, chore, contract, deploy, security
```

## Key Security Features

1. **Timelock Protection:** `MarketplaceTimelock` enforces 48-hour delay on critical operations
2. **Emergency Controls:** Pause/unpause via `EmergencyManager`
3. **Access Control:** Role-based permissions for admin operations
4. **Reentrancy Guards:** All critical functions protected
5. **Input Validation:** Dedicated validator contracts prevent invalid states
6. **Safe Transfers:** NFTTransferLib handles all NFT movements

## Current Status

⚠️ **Not yet audited** - Do not use in production without professional security audit.

The codebase is under active development with recent critical security improvements (Priority 1 fixes) completed on the `fix/critical-security-improvements` branch.
