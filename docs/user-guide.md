# Marketplace Hub - Production Architecture Guide

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Code Structure & Guidelines](#code-structure--guidelines)
3. [Frontend Integration](#frontend-integration)
4. [Deployment Guide](#deployment-guide)
5. [Testing](#testing)

---

## Architecture Overview

### Philosophy: Simplicity First

**Core Principle:** MarketplaceHub provides address discovery ONLY. It does NOT wrap function calls.

```
Frontend
   ↓ (Only needs 1 address)
MarketplaceHub
   ↓ (Provides addresses)
Registries → Core Contracts
   ↑
Frontend calls directly
```

### Benefits
- **Simple**: 1 address instead of 10+
- **Fast**: Minimal gas (address lookups only)
- **Flexible**: Add features without frontend changes
- **Maintainable**: Clear separation of concerns

### Key Components

**MarketplaceHub** (`src/router/MarketplaceHub.sol`)
- Single entry point for address discovery
- View-only functions (no state changes)
- Helper queries (fees, verification)

**Registries** (`src/registry/`)
- `ExchangeRegistry` - ERC721/ERC1155 exchange routing
- `CollectionRegistry` - Factory management
- `FeeRegistry` - Unified fee calculations
- `AuctionRegistry` - Auction contract routing

---

## Code Structure & Guidelines

### Directory Organization

```
src/
├── registry/                    # Registry contracts
│   ├── ExchangeRegistry.sol
│   ├── CollectionRegistry.sol
│   ├── FeeRegistry.sol
│   └── AuctionRegistry.sol
│
├── router/                      # Hub contract
│   └── MarketplaceHub.sol
│
├── interfaces/
│   ├── registry/               # Registry interfaces
│   ├── router/                 # Hub interface
│   └── core/                   # Core contract interfaces
│
└── core/                       # Business logic (unchanged)
    ├── exchange/
    ├── collection/
    ├── auction/
    └── fees/
```

### Coding Standards

#### 1. Interface Design
```solidity
// ✅ Good: Clear, focused interface
interface IExchangeRegistry {
    function getExchangeForToken(address nftContract) external view returns (address);
    function registerExchange(TokenStandard standard, address exchange) external;
}

// ❌ Bad: Mixed concerns
interface IBadRegistry {
    function getExchange() external view returns (address);
    function executeTradeViaExchange() external; // Should not wrap calls
}
```

#### 2. Registry Pattern
```solidity
// Registry only maps and provides addresses
contract ExchangeRegistry {
    mapping(TokenStandard => address) private s_exchanges;

    function getExchangeForToken(address nftContract) public view returns (address) {
        // Auto-detect via ERC165
        if (IERC165(nftContract).supportsInterface(type(IERC721).interfaceId)) {
            return s_exchanges[TokenStandard.ERC721];
        }
        // ...
    }
}
```

#### 3. Hub Design
```solidity
// Hub provides addresses and helper queries ONLY
contract MarketplaceHub {
    // ✅ Good: Address discovery
    function getAllAddresses() external view returns (...) {}
    function getExchangeFor(address nft) external view returns (address) {}

    // ✅ Good: Helper queries (no state changes)
    function calculateFees(...) external view returns (FeeBreakdown memory) {}

    // ❌ Bad: Never wrap transactions
    // function executeTrade(...) external {} // WRONG!
}
```

#### 4. Access Control
```solidity
// Use AccessControl for registries
contract Registry is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function registerContract(...) external onlyRole(ADMIN_ROLE) {
        // Only admin can register
    }

    function getContract(...) external view {
        // Anyone can query
    }
}
```

### Development Workflow

#### Adding New Token Standard (e.g., ERC6551)

**Step 1:** Add to enum
```solidity
// src/interfaces/registry/IExchangeRegistry.sol
enum TokenStandard {
    ERC721,
    ERC1155,
    ERC6551  // Add here
}
```

**Step 2:** Deploy exchange contract
```bash
forge create src/core/exchange/ERC6551NFTExchange.sol
```

**Step 3:** Register with registry
```solidity
exchangeRegistry.registerExchange(
    TokenStandard.ERC6551,
    erc6551ExchangeAddress
);
```

**Step 4:** Done! Hub automatically supports it
```typescript
// Frontend code unchanged
const exchange = await hub.getExchangeFor(erc6551NFT); // Works!
```

### File Naming Conventions

- Contracts: `PascalCase.sol` (e.g., `MarketplaceHub.sol`)
- Interfaces: `I + PascalCase.sol` (e.g., `IMarketplaceHub.sol`)
- Scripts: `PascalCase.s.sol` (e.g., `DeployMarketplaceHub.s.sol`)
- Tests: `ContractName.t.sol` (e.g., `MarketplaceHub.t.sol`)

### Code Comments

```solidity
/**
 * @title MarketplaceHub
 * @notice Single entry point for address discovery
 * @dev Does NOT wrap function calls - provides addresses only
 */
contract MarketplaceHub {
    /**
     * @notice Get all contract addresses in one call
     * @return erc721Exchange ERC721 exchange address
     * @return erc1155Exchange ERC1155 exchange address
     * // ... other returns
     */
    function getAllAddresses() external view returns (...) {}
}
```

---

## Frontend Integration

### Quick Start

#### 1. Setup (Only 1 Address Needed!)

```typescript
// config.ts
export const MARKETPLACE_HUB = '0x...'; // Only address needed!

// Initialize
import { ethers } from 'ethers';
import MarketplaceHubABI from './abis/MarketplaceHub.json';

const hub = new ethers.Contract(MARKETPLACE_HUB, MarketplaceHubABI, provider);
```

#### 2. Get All Addresses

```typescript
// Get everything in one call
const {
  erc721Exchange,
  erc1155Exchange,
  erc721Factory,
  erc1155Factory,
  englishAuction,
  dutchAuction,
  auctionFactory,
  feeRegistry
} = await hub.getAllAddresses();

// Create contract instances
const erc721ExchangeContract = new ethers.Contract(
  erc721Exchange,
  ERC721ExchangeABI,
  signer
);
```

#### 3. Auto-Detect NFT Type & List

```typescript
async function listNFT(
  nftAddress: string,
  tokenId: number,
  price: string
) {
  // Hub auto-detects ERC721 vs ERC1155
  const exchangeAddr = await hub.getExchangeFor(nftAddress);

  // Create exchange instance
  const exchange = new ethers.Contract(exchangeAddr, ExchangeABI, signer);

  // Call directly (NOT through hub!)
  const tx = await exchange.listNFT(
    nftAddress,
    tokenId,
    ethers.parseEther(price),
    86400 // duration
  );

  return tx.wait();
}
```

#### 4. Calculate Fees

```typescript
// Use hub helper function
const fees = await hub.calculateFees(
  nftAddress,
  tokenId,
  ethers.parseEther(price)
);

console.log('Platform fee:', ethers.formatEther(fees.platformFee));
console.log('Royalty:', ethers.formatEther(fees.royaltyFee));
console.log('Seller receives:', ethers.formatEther(fees.sellerProceeds));
```

### Complete Integration Example

```typescript
// marketplace.ts
import { ethers, Contract, Provider, Signer } from 'ethers';

class Marketplace {
  private hub: Contract;
  private exchanges: { [key: string]: Contract } = {};
  private factories: { [key: string]: Contract } = {};
  private auctions: { [key: string]: Contract } = {};

  async initialize(provider: Provider, hubAddress: string) {
    // 1. Create hub instance
    this.hub = new ethers.Contract(hubAddress, HubABI, provider);

    // 2. Get all addresses
    const addresses = await this.hub.getAllAddresses();

    // 3. Cache contract instances
    this.exchanges.erc721 = new ethers.Contract(
      addresses.erc721Exchange,
      ERC721ExchangeABI,
      provider
    );

    this.exchanges.erc1155 = new ethers.Contract(
      addresses.erc1155Exchange,
      ERC1155ExchangeABI,
      provider
    );

    this.factories.erc721 = new ethers.Contract(
      addresses.erc721Factory,
      ERC721FactoryABI,
      provider
    );

    // ... cache other contracts

    console.log('Marketplace initialized with hub:', hubAddress);
  }

  // List NFT with auto-detection
  async listNFT(
    nftAddress: string,
    tokenId: number,
    price: string,
    signer: Signer
  ) {
    const exchangeAddr = await this.hub.getExchangeFor(nftAddress);
    const exchange = new ethers.Contract(exchangeAddr, ExchangeABI, signer);

    return exchange.listNFT(
      nftAddress,
      tokenId,
      ethers.parseEther(price),
      86400
    );
  }

  // Buy NFT
  async buyNFT(listingId: string, price: string, signer: Signer) {
    // Get exchange from listing ID (would need registry mapping)
    // For simplicity, assuming you know which exchange
    const exchange = this.exchanges.erc721.connect(signer);

    return exchange.buyListedNFT(listingId, {
      value: ethers.parseEther(price)
    });
  }

  // Create collection
  async createCollection(
    type: 'ERC721' | 'ERC1155',
    params: CollectionParams,
    signer: Signer
  ) {
    const factoryAddr = await this.hub.getCollectionFactory(type);
    const factory = new ethers.Contract(factoryAddr, FactoryABI, signer);

    return factory[`create${type}Collection`](params);
  }

  // Create auction
  async createEnglishAuction(
    nftAddress: string,
    tokenId: number,
    startPrice: string,
    duration: number,
    signer: Signer
  ) {
    const auctionAddr = await this.hub.getEnglishAuction();
    const auction = new ethers.Contract(auctionAddr, AuctionABI, signer);

    return auction.createAuction(
      nftAddress,
      tokenId,
      1, // amount
      ethers.parseEther(startPrice),
      0, // reserve price
      duration,
      0, // AuctionType.ENGLISH
      await signer.getAddress()
    );
  }

  // Helper: Calculate fees
  async getFees(nft: string, tokenId: number, price: string) {
    const fees = await this.hub.calculateFees(
      nft,
      tokenId,
      ethers.parseEther(price)
    );

    return {
      platformFee: ethers.formatEther(fees.platformFee),
      royaltyFee: ethers.formatEther(fees.royaltyFee),
      sellerReceives: ethers.formatEther(fees.sellerProceeds)
    };
  }

  // Helper: Verify collection
  async verifyCollection(address: string) {
    const [isValid, tokenType] = await this.hub.verifyCollection(address);
    return { isValid, tokenType };
  }
}

// Usage
const marketplace = new Marketplace();
await marketplace.initialize(provider, MARKETPLACE_HUB);

// List NFT
await marketplace.listNFT(nftAddress, tokenId, '1.5', signer);

// Calculate fees
const fees = await marketplace.getFees(nftAddress, tokenId, '1.5');
console.log(fees);
```

### React Hook Example

```typescript
// useMarketplace.ts
import { useContract, useSigner, useProvider } from 'wagmi';
import { useState, useEffect } from 'react';

export function useMarketplace(hubAddress: string) {
  const provider = useProvider();
  const { data: signer } = useSigner();
  const [addresses, setAddresses] = useState<any>(null);

  const hub = useContract({
    address: hubAddress,
    abi: MarketplaceHubABI,
    signerOrProvider: provider
  });

  useEffect(() => {
    async function loadAddresses() {
      const addrs = await hub.getAllAddresses();
      setAddresses(addrs);
    }
    loadAddresses();
  }, [hub]);

  const listNFT = async (nft: string, tokenId: number, price: string) => {
    const exchangeAddr = await hub.getExchangeFor(nft);
    const exchange = new Contract(exchangeAddr, ExchangeABI, signer!);
    return exchange.listNFT(nft, tokenId, parseEther(price), 86400);
  };

  const calculateFees = async (nft: string, tokenId: number, price: string) => {
    return hub.calculateFees(nft, tokenId, parseEther(price));
  };

  return {
    hub,
    addresses,
    listNFT,
    calculateFees
  };
}
```

### Best Practices

#### ✅ DO:
```typescript
// Cache addresses after initialization
const addresses = await hub.getAllAddresses();
const exchange = new Contract(addresses.erc721Exchange, ABI, signer);

// Use auto-detection
const exchangeAddr = await hub.getExchangeFor(nftAddress);

// Call contracts directly
await exchange.listNFT(...);
```

#### ❌ DON'T:
```typescript
// Don't query hub every time (wasteful)
const addr = await hub.getERC721Exchange(); // Bad if repeated

// Don't implement manual detection (hub does it)
const isERC721 = await nft.supportsInterface('0x80ac58cd'); // Unnecessary

// Don't try to call through hub (it doesn't wrap)
await hub.listNFT(...); // This function doesn't exist!
```

---

## Deployment Guide

### Single-Script Deployment

Deploy the entire marketplace with **one command** using `DeployAll.s.sol`. This script deploys ALL contracts in the correct order and automatically configures the MarketplaceHub.

### Environment Setup

```bash
# .env
MARKETPLACE_WALLET=0x...  # Admin address
PRIVATE_KEY=0x...         # Deployer private key
SEPOLIA_RPC_URL=https://...  # RPC URL
```

### Deploy Everything

```bash
# Deploy all contracts + MarketplaceHub in one command
forge script script/deploy/DeployAll.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

### Deployment Output

```
========================================
  COMPLETE MARKETPLACE DEPLOYMENT
========================================
Admin: 0x...

1/6 Deploying Access Control...
  AccessControl: 0x...
2/6 Deploying Fee System...
  BaseFee: 0x...
  FeeManager: 0x...
  RoyaltyManager: 0x...
3/6 Deploying Exchanges...
  ERC721Exchange: 0x...
  ERC1155Exchange: 0x...
  ExchangeRegistry: 0x...
4/6 Deploying Collection Factories...
  ERC721Factory: 0x...
  ERC1155Factory: 0x...
  FactoryRegistry: 0x...
5/6 Deploying Auction System...
  EnglishAuction: 0x...
  DutchAuction: 0x...
  AuctionFactory: 0x...
6/6 Deploying MarketplaceHub...
  HubExchangeRegistry: 0x...
  HubCollectionRegistry: 0x...
  HubFeeRegistry: 0x...
  HubAuctionRegistry: 0x...
  MarketplaceHub: 0x...

========================================
  DEPLOYMENT COMPLETE!
========================================

CORE CONTRACTS:
  ERC721Exchange:     0x...
  ERC1155Exchange:    0x...
  ERC721Factory:      0x...
  ERC1155Factory:     0x...
  EnglishAuction:     0x...
  DutchAuction:       0x...
  BaseFee:            0x...
  FeeManager:         0x...
  RoyaltyManager:     0x...

========================================
  FOR FRONTEND INTEGRATION
========================================
  MarketplaceHub:     0x...

Frontend only needs this ONE address!

Copy this to your .env:
MARKETPLACE_HUB= 0x...

========================================
```

### Post-Deployment

1. **Share with Frontend Team:**
   - MarketplaceHub address only

2. **Update Environment:**
   ```bash
   export MARKETPLACE_HUB=0x...
   ```

3. **Test Integration:**
   ```typescript
   const hub = new Contract(MARKETPLACE_HUB, ABI, provider);
   const addresses = await hub.getAllAddresses();
   console.log(addresses);
   ```

---

## Testing

### Test Structure

```
test/
├── unit/
│   ├── registry/               # Registry unit tests
│   │   ├── ExchangeRegistry.t.sol
│   │   ├── CollectionRegistry.t.sol
│   │   └── FeeRegistry.t.sol
│   └── router/                 # Hub unit tests
│       └── MarketplaceHub.t.sol
│
├── integration/                # Integration tests
│   └── HubIntegration.t.sol
│
└── e2e/                       # E2E tests with hub
    └── E2E_WithHub.t.sol
```

### Unit Test Example

```solidity
// test/unit/router/MarketplaceHub.t.sol
contract MarketplaceHubTest is Test {
    MarketplaceHub hub;
    ExchangeRegistry exchangeRegistry;

    function setUp() public {
        // Deploy registries
        exchangeRegistry = new ExchangeRegistry(admin);
        // ... deploy other registries

        // Deploy hub
        hub = new MarketplaceHub(
            admin,
            address(exchangeRegistry),
            address(collectionRegistry),
            address(feeRegistry),
            address(auctionRegistry)
        );

        // Register contracts
        exchangeRegistry.registerExchange(
            IExchangeRegistry.TokenStandard.ERC721,
            address(erc721Exchange)
        );
    }

    function test_GetAllAddresses() public {
        (
            address erc721Ex,
            address erc1155Ex,
            // ...
        ) = hub.getAllAddresses();

        assertEq(erc721Ex, address(erc721Exchange));
    }

    function test_AutoDetectERC721() public {
        address exchange = hub.getExchangeFor(address(mockERC721));
        assertEq(exchange, address(erc721Exchange));
    }
}
```

### Integration Test Example

```solidity
// test/integration/HubIntegration.t.sol
contract HubIntegrationTest is Test {
    MarketplaceHub hub;

    function test_ListAndBuyNFT() public {
        // Get exchange from hub
        address exchangeAddr = hub.getExchangeFor(address(nft));
        IERC721NFTExchange exchange = IERC721NFTExchange(exchangeAddr);

        // List NFT
        vm.prank(seller);
        exchange.listNFT(address(nft), tokenId, price, duration);

        // Buy NFT
        vm.prank(buyer);
        exchange.buyListedNFT{value: price}(listingId);

        // Verify
        assertEq(nft.ownerOf(tokenId), buyer);
    }
}
```

### E2E Test with Hub

```solidity
// test/e2e/E2E_WithHub.t.sol
contract E2E_WithHub is Test {
    MarketplaceHub hub;

    function setUp() public {
        // Deploy everything via hub
        hub = deployMarketplaceHub();
    }

    function test_CompleteFlow() public {
        // 1. Create collection via hub
        address factoryAddr = hub.getCollectionFactory("ERC721");
        address collection = IFactory(factoryAddr).createERC721Collection(...);

        // 2. Mint NFT
        IERC721(collection).mint(seller, tokenId);

        // 3. List via auto-detected exchange
        address exchangeAddr = hub.getExchangeFor(collection);
        IExchange(exchangeAddr).listNFT(...);

        // 4. Calculate fees
        IFeeRegistry.FeeBreakdown memory fees = hub.calculateFees(
            collection,
            tokenId,
            price
        );

        // 5. Buy
        IExchange(exchangeAddr).buyListedNFT{value: price}(listingId);

        // Verify
        assertEq(IERC721(collection).ownerOf(tokenId), buyer);
    }
}
```

### Run Tests

```bash
# All tests
forge test

# Specific test file
forge test --match-path test/unit/router/MarketplaceHub.t.sol

# With gas report
forge test --gas-report

# With coverage
forge coverage
```

---

## Summary

### Key Principles

1. **Simplicity**: Hub provides addresses, frontend calls directly
2. **Separation**: Registries map, Hub queries, Core executes
3. **Flexibility**: Add features without frontend changes
4. **Performance**: Minimal gas, maximum efficiency

### Integration Checklist

- [ ] Get MarketplaceHub address from deployment
- [ ] Initialize with `getAllAddresses()`
- [ ] Cache contract instances
- [ ] Use `getExchangeFor()` for auto-detection
- [ ] Call contracts directly (not through hub)
- [ ] Use hub helpers for fees/verification

### Development Checklist

- [ ] Follow directory structure (`registry/`, `router/`, `interfaces/`)
- [ ] Create interfaces for all contracts
- [ ] Use AccessControl for admin functions
- [ ] Write view-only hub functions
- [ ] Test with unit + integration + e2e tests
- [ ] Document with clear NatSpec comments

**Philosophy**: Keep it simple. Hub discovers addresses. Frontend calls directly. Production-ready architecture.
