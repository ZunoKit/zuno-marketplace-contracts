# Registries API

Unified references for Exchange, Collection, Auction, and Fee registries.

## ExchangeRegistry (IExchangeRegistry)

### Enums

```solidity
enum TokenStandard { ERC721, ERC1155, ERC6551, ERC404 }
```

### Queries

```solidity
function getExchange(TokenStandard standard) external view returns (address)
function getExchangeForToken(address nftContract) external view returns (address)
function getExchangeForListing(bytes32 listingId) external view returns (address)
function isRegisteredExchange(address exchange) external view returns (bool)
function getAllExchanges() external view returns (TokenStandard[] memory, address[] memory)
```

### Admin

```solidity
function registerExchange(TokenStandard standard, address exchange) external
function updateExchange(TokenStandard standard, address newExchange) external
```

## CollectionRegistry (ICollectionRegistry)

### Queries

```solidity
function getFactory(string memory tokenType) external view returns (address)
function verifyCollection(address collection) external view returns (bool isValid, string memory tokenType)
function isRegisteredFactory(address factory) external view returns (bool)
function getAllFactories() external view returns (string[] memory tokenTypes, address[] memory factories)
```

### Admin

```solidity
function registerFactory(string memory tokenType, address factory) external
function updateFactory(string memory tokenType, address newFactory) external
```

## AuctionRegistry (IAuctionRegistry)

### Enums

```solidity
enum AuctionType { ENGLISH, DUTCH, SEALED_BID }
```

### Queries

```solidity
function getAuctionContract(AuctionType auctionType) external view returns (address)
function getAuctionFactory() external view returns (address)
function isRegisteredAuction(address auctionContract) external view returns (bool)
function getAllAuctions() external view returns (AuctionType[] memory types, address[] memory contracts)
```

### Admin

```solidity
function registerAuction(AuctionType auctionType, address auctionContract) external
function updateAuctionFactory(address newFactory) external
```

## FeeRegistry (IFeeRegistry)

### Types

```solidity
struct FeeBreakdown {
    uint256 platformFee;
    uint256 royaltyFee;
    address royaltyRecipient;
    uint256 totalFees;
    uint256 sellerProceeds;
}
```

### Queries

```solidity
function calculateAllFees(address nftContract, uint256 tokenId, uint256 salePrice)
    external view returns (FeeBreakdown memory)
function calculatePlatformFee(uint256 salePrice) external view returns (uint256)
function calculateRoyalty(address nftContract, uint256 tokenId, uint256 salePrice)
    external view returns (address recipient, uint256 amount)
function getPlatformFeePercentage() external view returns (uint256)
function getBaseFeeContract() external view returns (address)
function getFeeManagerContract() external view returns (address)
function getRoyaltyManagerContract() external view returns (address)
```

### Admin

```solidity
function updateFeeContracts(address baseFee, address feeManager, address royaltyManager) external
```
