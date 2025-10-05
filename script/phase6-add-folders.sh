#!/bin/bash
# Phase 6: Add missing folders and documentation

echo "➕ PHASE 6: Adding missing folders and documentation..."

# Create governance and proxy folders
mkdir -p src/core/{governance,proxy}
touch src/core/governance/.gitkeep
touch src/core/proxy/.gitkeep

# Create docs structure
mkdir -p docs/{architecture,security,api,deployment,guides}

# Create architecture docs
cat > docs/architecture/overview.md << 'EOF'
# Architecture Overview

## System Design

The Zuno NFT Marketplace follows a modular layered architecture:

### Layers

1. **Collections Layer** - NFT collection implementations (ERC721/ERC1155)
2. **Exchange Layer** - Core trading logic
3. **Marketplace Layer** - Advanced features (listings, offers, bundles)
4. **Management Layer** - Fees, royalties, emergency controls
5. **Access & Validation Layer** - RBAC and validation

## Key Design Patterns

- **Factory Pattern**: Gas-efficient collection deployment
- **Registry Pattern**: Centralized contract management
- **Modular Architecture**: Independent upgradeable components
- **Role-based Access Control**: Secure permission management

## Contract Interactions

[To be documented with diagrams]
EOF

cat > docs/architecture/contracts.md << 'EOF'
# Contract Reference

## Core Contracts

### Exchange Layer
- **ERC721NFTExchange**: Trading logic for ERC721 tokens
- **ERC1155NFTExchange**: Trading logic for ERC1155 tokens
- **NFTExchangeRegistry**: Central exchange management

### Collection Layer
- **ERC721Collection**: ERC721 NFT implementation
- **ERC1155Collection**: ERC1155 NFT implementation
- **ERC721CollectionFactory**: Factory for ERC721 collections
- **ERC1155CollectionFactory**: Factory for ERC1155 collections

### Marketplace Layer
- **AdvancedListingManager**: Complex listing management
- **OfferManager**: Offer system for any NFT
- **BundleManager**: Multi-NFT bundle trading

### Management Layer
- **AdvancedFeeManager**: Configurable fee system
- **AdvancedRoyaltyManager**: EIP-2981 royalty distribution
- **EmergencyManager**: Emergency pause and recovery

[To be expanded with detailed documentation]
EOF

# Create security docs
cat > docs/security/security-model.md << 'EOF'
# Security Model

## Threat Model

### Attack Vectors
1. Reentrancy attacks
2. Front-running / MEV attacks
3. Access control bypass
4. Integer overflow/underflow
5. Price manipulation
6. NFT approval exploits

## Security Controls

### Access Control
- Role-based permissions (RBAC)
- Multi-sig governance for critical functions
- Timelock for parameter changes

### Attack Prevention
- ReentrancyGuard on all state-changing functions
- Checks-Effects-Interactions pattern
- Input validation on all external calls
- Safe math (Solidity 0.8+)

### Emergency Controls
- Pausable functionality
- Emergency withdraw mechanisms
- Admin override capabilities

## Audit Status

⚠️ **NOT AUDITED** - Do not use in production

Required before mainnet:
- [ ] Professional security audit
- [ ] Bug bounty program
- [ ] Formal verification (critical paths)

[To be updated with audit findings]
EOF

cat > docs/security/access-control.md << 'EOF'
# Access Control

## Roles

### ADMIN_ROLE
- Full system control
- Can grant/revoke roles
- Emergency functions

### OPERATOR_ROLE
- Marketplace operations
- Can pause/unpause specific features
- Fee management

### EMERGENCY_ROLE
- Emergency pause only
- Limited scope for security

## Permissions Matrix

| Function | Admin | Operator | Emergency | Public |
|----------|-------|----------|-----------|--------|
| Create Listing | ❌ | ❌ | ❌ | ✅ |
| Cancel Listing | ❌ | ❌ | ❌ | ✅ (owner) |
| Update Fees | ✅ | ✅ | ❌ | ❌ |
| Pause System | ✅ | ❌ | ✅ | ❌ |
| Withdraw Funds | ✅ | ❌ | ❌ | ❌ |

[To be expanded]
EOF

# Create API docs
cat > docs/api/contract-api.md << 'EOF'
# Contract API Reference

## NFT Exchange

### Core Functions

#### `createListing`
```solidity
function createListing(
    address nftContract,
    uint256 tokenId,
    uint256 price,
    uint256 duration
) external returns (bytes32 listingId)
```

Creates a new NFT listing.

**Parameters:**
- `nftContract`: Address of the NFT contract
- `tokenId`: Token ID to list
- `price`: Listing price in wei
- `duration`: Listing duration in seconds

**Returns:**
- `listingId`: Unique identifier for the listing

**Events:**
- `NFTListed(listingId, nftContract, tokenId, seller, price)`

---

[To be expanded with all functions]
EOF

# Create deployment docs
cat > docs/deployment/deployment-guide.md << 'EOF'
# Deployment Guide

## Prerequisites

- Foundry installed and configured
- RPC endpoints configured in `foundry.toml`
- Private keys secured in `.env` or hardware wallet
- Sufficient ETH for deployment gas

## Pre-deployment Checklist

- [ ] All tests passing (`forge test`)
- [ ] Security audit completed
- [ ] Contract parameters configured
- [ ] Multisig wallet setup
- [ ] Monitoring infrastructure ready

## Step-by-Step Deployment

### 1. Local Testing

```bash
# Start local chain
make start-anvil

# Deploy to local
make deploy-all-local

# Verify deployment
forge test --fork-url http://localhost:8545
```

### 2. Testnet Deployment (Sepolia)

```bash
# Set environment variables
export SEPOLIA_RPC_URL="https://..."
export PRIVATE_KEY="0x..."
export MARKETPLACE_WALLET="0x..."

# Deploy
forge script script/deploy/01_DeployExchanges.s.sol \\
  --rpc-url $SEPOLIA_RPC_URL \\
  --broadcast \\
  --verify

# Verify contracts
forge verify-contract <address> <contract> --chain sepolia
```

### 3. Mainnet Deployment

⚠️ **CRITICAL**: Use hardware wallet and multisig

```bash
# Additional mainnet checks
- [ ] Audit report reviewed
- [ ] Parameters double-checked
- [ ] Multisig configured
- [ ] Emergency procedures documented

# Deploy (use Ledger/Trezor)
forge script script/deploy/01_DeployExchanges.s.sol \\
  --rpc-url $MAINNET_RPC_URL \\
  --ledger \\
  --broadcast \\
  --verify
```

## Post-Deployment

1. Transfer ownership to multisig
2. Verify all contracts on Etherscan
3. Enable monitoring alerts
4. Gradual rollout (whitelist → public)
5. 24/7 monitoring for first week

[To be expanded]
EOF

cat > docs/deployment/upgrade-guide.md << 'EOF'
# Upgrade Guide

## Upgrade Strategy

Contracts use UUPS proxy pattern for upgradeability.

## Preparation

1. Test upgrade on fork
2. Get multisig approval
3. Queue timelock transaction
4. Prepare rollback procedure

## Upgrade Process

[To be documented after proxy implementation]

## Rollback Procedure

[To be documented]
EOF

# Create integration guide
cat > docs/guides/integration-guide.md << 'EOF'
# Integration Guide

## For Frontend Developers

### Installing Dependencies

```bash
npm install ethers@^6.0.0
```

### Contract ABIs

ABIs are available in `/abis` directory after running:
```bash
make update-abi
```

### Basic Integration Example

```javascript
import { ethers } from 'ethers';
import ERC721Exchange from './abis/ERC721NFTExchange.json';

const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

const exchange = new ethers.Contract(
  EXCHANGE_ADDRESS,
  ERC721Exchange.abi,
  signer
);

// Create listing
const tx = await exchange.createListing(
  nftAddress,
  tokenId,
  ethers.parseEther("1.0"),
  86400 // 1 day
);
await tx.wait();
```

## For Smart Contract Integration

[To be documented]
EOF

echo "✅ PHASE 6 COMPLETE: All folders and documentation created"
