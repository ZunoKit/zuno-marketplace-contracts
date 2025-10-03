# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Build and Test
```bash
# Build all contracts
forge build

# Run all tests
forge test

# Run tests with verbosity for debugging
forge test -vvv

# Run specific test file
forge test --match-path test/unit/collection/unit/UnitERC721CollectionTest.t.sol

# Run tests matching a pattern
forge test --match-test testCreateCollection
```

### Local Development
```bash
# Start local Anvil blockchain (runs on port 8545)
make start-anvil
# OR directly: anvil --port 8545

# Deploy all contracts to local network
make deploy-all-local
# OR directly: forge script script/DeployExchanges.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

# Update ABI files after deployment
make update-abi
# OR directly: node extract-abis.js
```

### Deployment Scripts
- `script/DeployExchanges.s.sol` - Deploys core NFT exchanges
- `script/DeployCollections.s.sol` - Deploys collection factories and related contracts

## Architecture Overview

This is a comprehensive NFT marketplace built with Foundry using a modular architecture pattern. The system supports both ERC721 and ERC1155 tokens with advanced trading features.

### Core Architecture Layers

**Collections Layer** (4 contracts)
- `ERC721Collection` / `ERC1155Collection` - NFT collection implementations
- `ERC721CollectionFactory` / `ERC1155CollectionFactory` - Factory pattern for creating collections
- Uses proxy pattern for gas-efficient deployments

**Exchange Layer** (3 contracts)
- `ERC721NFTExchange` / `ERC1155NFTExchange` - Core trading logic for different token standards
- `NFTExchangeRegistry` - Central registry for managing exchange contracts
- Handles direct sales, offers, and basic trading operations

**Marketplace Layer** (3 contracts)
- `AdvancedListingManager` - Complex listing logic and management
- `OfferManager` - Offer system for any NFT in the marketplace
- `BundleManager` - Bundle trading for multiple NFTs together

**Management Layer** (3 contracts)
- `AdvancedFeeManager` - Configurable marketplace and service fees
- `AdvancedRoyaltyManager` - EIP-2981 royalty distribution system
- `EmergencyManager` - Emergency pause and recovery controls

**Access & Validation Layer** (4 contracts)
- `MarketplaceAccessControl` - Role-based access control system
- `CollectionVerifier` - Validates collection contracts before marketplace integration
- `ListingValidator` - Validates listing parameters and business rules
- `ListingHistoryTracker` - Tracks historical data for analytics

### Key Design Patterns

**Factory Pattern**: Collections are deployed through factories using minimal proxy pattern for gas efficiency

**Registry Pattern**: Central registries manage and validate contract relationships

**Modular Architecture**: Each layer can be upgraded independently while maintaining compatibility

**Access Control**: Role-based permissions with emergency controls for security

### Dependencies
- OpenZeppelin Contracts (remapped to `@openzeppelin/contracts`)
- Foundry framework for development and testing

### Test Structure
- `test/unit/` - Unit tests for individual contracts organized by feature
- `test/integration/` - Integration tests for cross-contract workflows
- `test/mocks/` - Mock contracts for testing
- `test/utils/` - Shared testing utilities and helpers

### Development Notes
- All contracts use Solidity ^0.8.30
- Optimization enabled with 200 runs
- Tests extensively cover edge cases and error conditions
- Uses custom error definitions for gas efficiency
- Event-driven architecture for frontend integration