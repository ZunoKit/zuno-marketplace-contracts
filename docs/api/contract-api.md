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
