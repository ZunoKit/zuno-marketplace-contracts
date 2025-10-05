# MarketplaceHub API

MarketplaceHub is a read-only address discovery and helper query contract. Frontend only needs this one address and should call core contracts directly.

## Address Discovery

### `getExchangeFor`

```solidity
function getExchangeFor(address nftContract) external view returns (address)
```

Returns the exchange address for the given NFT contract (auto-detects ERC721 vs ERC1155 via ERC165).

### `getERC721Exchange`

```solidity
function getERC721Exchange() external view returns (address)
```

### `getERC1155Exchange`

```solidity
function getERC1155Exchange() external view returns (address)
```

### `getCollectionFactory`

```solidity
function getCollectionFactory(string memory tokenType) external view returns (address)
```

`tokenType` is "ERC721" or "ERC1155".

### `getEnglishAuction`

```solidity
function getEnglishAuction() external view returns (address)
```

### `getDutchAuction`

```solidity
function getDutchAuction() external view returns (address)
```

### `getAuctionFactory`

```solidity
function getAuctionFactory() external view returns (address)
```

## Fee Queries

### `calculateFees`

```solidity
function calculateFees(
    address nftContract,
    uint256 tokenId,
    uint256 salePrice
) external view returns (IFeeRegistry.FeeBreakdown memory breakdown)
```

Returns platform fee, royalty fee and seller proceeds.

### `getPlatformFeePercentage`

```solidity
function getPlatformFeePercentage() external view returns (uint256)
```

Returns platform fee in basis points.

## Collection Verification

### `verifyCollection`

```solidity
function verifyCollection(address collection)
    external
    view
    returns (bool isValid, string memory tokenType)
```

Verifies a collection was created by a registered factory and returns its token type ("ERC721" or "ERC1155").

## Registry Accessors

### `getExchangeRegistry`

```solidity
function getExchangeRegistry() external view returns (address)
```

### `getCollectionRegistry`

```solidity
function getCollectionRegistry() external view returns (address)
```

### `getFeeRegistry`

```solidity
function getFeeRegistry() external view returns (address)
```

### `getAuctionRegistry`

```solidity
function getAuctionRegistry() external view returns (address)
```

## Batch Query

### `getAllAddresses`

```solidity
function getAllAddresses()
    external
    view
    returns (
        address erc721Exchange,
        address erc1155Exchange,
        address erc721Factory,
        address erc1155Factory,
        address englishAuction,
        address dutchAuction,
        address auctionFactory,
        address feeRegistryAddr
    )
```

## Admin

### `updateRegistry`

```solidity
function updateRegistry(string memory registryType, address newRegistry) external
```

`registryType` is one of: "exchange", "collection", "fee", "auction". Restricted to `ADMIN_ROLE`.
