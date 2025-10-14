# 🔗 Zuno Marketplace - Frontend Integration Guide

## 📋 Table of Contents
- [Quick Start](#-quick-start)
- [Contract Addresses](#-contract-addresses)
- [Core Functions](#-core-functions)
- [Advanced Features](#-advanced-features)
- [Events](#-events)
- [Error Handling](#-error-handling)

## 🚀 Quick Start

### 1. Initialize with MarketplaceHub

Frontend only needs **ONE** contract address:

```javascript
// This is the ONLY address you need to store
const MARKETPLACE_HUB = "0x..."; // Get from deployment output

// Initialize hub
const hub = new ethers.Contract(MARKETPLACE_HUB, HubABI, signer);

// Get all other contract addresses
const addresses = await hub.getAllAddresses();
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
} = addresses;
```

### 2. Automatic Exchange Detection

```javascript
// Hub automatically detects which exchange to use
const exchangeAddress = await hub.getExchangeFor(nftContract);
const exchange = new ethers.Contract(exchangeAddress, ExchangeABI, signer);
```

## 📍 Contract Addresses

After deployment, you'll get:

```
MarketplaceHub: 0x... (SAVE THIS!)
```

All other addresses can be retrieved via hub:

```javascript
// Get individual addresses
const erc721Exchange = await hub.getERC721Exchange();
const erc1155Exchange = await hub.getERC1155Exchange();
const offerManager = await hub.getOfferManager();
const bundleManager = await hub.getBundleManager();
```

## 🔧 Core Functions

### 1. Listing NFTs

#### Fixed Price Listing (ERC721)

```javascript
// 1. Approve marketplace
await nft.approve(exchangeAddress, tokenId);

// 2. List NFT
await exchange.listNFT(
  nftContract,     // NFT contract address
  tokenId,         // Token ID
  price,           // Price in wei
  duration         // Listing duration in seconds
);

// Get listing ID
const listingId = await exchange.getGeneratedListingId(nftContract, tokenId, seller);
```

#### Batch Listing (ERC721)

```javascript
// Approve all
await nft.setApprovalForAll(exchangeAddress, true);

// Batch list
await exchange.batchListNFT(
  nftContract,     // NFT contract address
  tokenIds,        // Array of token IDs
  prices,          // Array of prices
  duration         // Same duration for all
);
```

#### ERC1155 Listing

```javascript
// Approve
await nft1155.setApprovalForAll(exchangeAddress, true);

// List with amount
await erc1155Exchange.listNFT(
  nftContract,
  tokenId,
  amount,          // Number of tokens to list
  pricePerToken,   // Price per token
  duration
);
```

### 2. Buying NFTs

#### Direct Purchase

```javascript
// Calculate fees first
const fees = await hub.calculateFees(nftContract, tokenId, price);
const totalPrice = fees.totalPrice; // Includes platform fee & royalty

// Buy NFT
await exchange.buyNFT(listingId, {
  value: totalPrice
});
```

#### Batch Purchase

```javascript
// Get batch price
const breakdown = await exchange.getBatchPriceBreakdown(listingIds);
const totalPrice = breakdown.totalPrice;

// Buy multiple
await exchange.batchBuyNFT(listingIds, {
  value: totalPrice
});
```

### 3. Auctions

#### Create English Auction

```javascript
const auctionFactory = new ethers.Contract(auctionFactoryAddress, FactoryABI, signer);

// Approve NFT
await nft.approve(auctionFactoryAddress, tokenId);

// Create auction
const tx = await auctionFactory.createEnglishAuction(
  nftContract,
  tokenId,
  amount,           // 1 for ERC721
  startingPrice,    // Minimum bid
  reservePrice,     // Optional reserve (0 for none)
  duration          // Auction duration
);

// Get auction ID from event
const receipt = await tx.wait();
const auctionId = receipt.events[0].args.auctionId;
```

#### Place Bid (English)

```javascript
const englishAuction = new ethers.Contract(englishAuctionAddress, AuctionABI, signer);

await englishAuction.placeBid(auctionId, {
  value: bidAmount
});
```

#### Create Dutch Auction

```javascript
await auctionFactory.createDutchAuction(
  nftContract,
  tokenId,
  amount,
  startingPrice,   // High starting price
  endingPrice,     // Low ending price
  duration         // Price decrease duration
);
```

#### Buy Dutch Auction

```javascript
const dutchAuction = new ethers.Contract(dutchAuctionAddress, AuctionABI, signer);

// Get current price
const currentPrice = await dutchAuction.getCurrentPrice(auctionId);

// Buy at current price
await dutchAuction.buyNow(auctionId, {
  value: currentPrice
});
```

### 4. Offers

#### Make Offer on NFT

```javascript
const offerManager = new ethers.Contract(offerManagerAddress, OfferABI, signer);

// ETH offer
const offerId = await offerManager.createNFTOffer(
  collection,
  tokenId,
  offerAmount,
  duration,
  {
    value: offerAmount  // Lock ETH
  }
);

// ERC20 offer (approve token first)
await token.approve(offerManagerAddress, offerAmount);
await offerManager.createNFTOfferWithToken(
  collection,
  tokenId,
  offerAmount,
  tokenAddress,
  duration
);
```

#### Accept Offer

```javascript
// As NFT owner
await nft.approve(offerManagerAddress, tokenId);
await offerManager.acceptNFTOffer(offerId);
```

#### Collection Offer

```javascript
// Make offer on any NFT in collection
await offerManager.createCollectionOffer(
  collection,
  pricePerNFT,
  quantity,      // How many NFTs you want
  duration,
  {
    value: pricePerNFT * quantity
  }
);
```

### 5. Bundles

#### Create Bundle

```javascript
const bundleManager = new ethers.Contract(bundleManagerAddress, BundleABI, signer);

// Approve all NFTs
for(const nft of nfts) {
  await nft.contract.approve(bundleManagerAddress, nft.tokenId);
}

// Create bundle
const bundleItems = [
  {
    nftContract: nft1Address,
    tokenId: 1,
    amount: 1,      // 1 for ERC721
    tokenType: 0    // 0 = ERC721, 1 = ERC1155
  },
  {
    nftContract: nft2Address,
    tokenId: 5,
    amount: 1,
    tokenType: 0
  }
];

const tx = await bundleManager.createBundle(
  bundleItems,
  totalPrice,     // Price for entire bundle
  duration
);

const receipt = await tx.wait();
const bundleId = receipt.events[0].args.bundleId;
```

#### Purchase Bundle

```javascript
// Get bundle details
const bundle = await bundleManager.getBundle(bundleId);

// Purchase
await bundleManager.purchaseBundle(bundleId, {
  value: bundle.totalPrice
});
```

### 6. Advanced Listing Manager

For complex listing types:

```javascript
const listingManager = new ethers.Contract(listingManagerAddress, ListingABI, signer);

// Create auction listing
await listingManager.createAuctionListing(
  nftContract,
  tokenId,
  auctionParams    // Starting bid, reserve, duration, etc.
);

// Create Dutch auction
await listingManager.createDutchAuctionListing(
  nftContract,
  tokenId,
  dutchParams      // Start price, end price, duration
);
```

## 📊 Reading Data

### Get Listing Details

```javascript
// Get listing info
const listing = await exchange.getListing(listingId);
/*
Returns:
{
  seller: address,
  contractAddress: address,
  tokenId: uint256,
  price: uint256,
  expirationTime: uint256,
  isActive: bool
}
*/
```

### Calculate Fees

```javascript
// Get complete fee breakdown
const fees = await hub.calculateFees(nftContract, tokenId, salePrice);
/*
Returns:
{
  platformFee: uint256,
  royaltyAmount: uint256,
  royaltyRecipient: address,
  sellerProceeds: uint256,
  totalPrice: uint256
}
*/
```

### Verify Collection

```javascript
// Check if collection is verified
const { isValid, tokenType } = await hub.verifyCollection(collectionAddress);
// tokenType: "ERC721" or "ERC1155"
```

## 🔔 Events

### Essential Events to Listen

```javascript
// Listing Events
exchange.on("NFTListed", (listingId, contractAddr, tokenId, seller, price) => {
  console.log("New listing:", listingId);
});

exchange.on("NFTSold", (listingId, buyer, price) => {
  console.log("NFT sold:", listingId);
});

exchange.on("ListingCancelled", (listingId) => {
  console.log("Listing cancelled:", listingId);
});

// Auction Events
auction.on("AuctionCreated", (auctionId, seller, nftContract, tokenId) => {
  console.log("Auction created:", auctionId);
});

auction.on("BidPlaced", (auctionId, bidder, amount) => {
  console.log("New bid:", amount);
});

auction.on("AuctionEnded", (auctionId, winner, amount) => {
  console.log("Auction ended, winner:", winner);
});

// Offer Events
offerManager.on("OfferCreated", (offerId, offerer, collection, tokenId, amount) => {
  console.log("New offer:", offerId);
});

offerManager.on("OfferAccepted", (offerId, seller) => {
  console.log("Offer accepted:", offerId);
});

// Bundle Events
bundleManager.on("BundleCreated", (bundleId, creator, totalPrice) => {
  console.log("Bundle created:", bundleId);
});

bundleManager.on("BundlePurchased", (bundleId, buyer) => {
  console.log("Bundle sold:", bundleId);
});
```

## ❌ Error Handling

### Common Errors

```javascript
try {
  await exchange.buyNFT(listingId, { value: price });
} catch (error) {
  if (error.message.includes("NFTExchange__InsufficientPayment")) {
    // Price + fees required
  } else if (error.message.includes("NFTExchange__ListingNotActive")) {
    // Already sold or expired
  } else if (error.message.includes("NFTExchange__CannotBuyOwnNFT")) {
    // Seller trying to buy own NFT
  }
}
```

### Custom Errors Reference

```solidity
// Exchange Errors
NFTExchange__InvalidMarketplaceWallet()
NFTExchange__PriceMustBeGreaterThanZero()
NFTExchange__DurationMustBeGreaterThanZero()
NFTExchange__NotTheOwner()
NFTExchange__MarketplaceNotApproved()
NFTExchange__ListingNotActive()
NFTExchange__InsufficientPayment()
NFTExchange__CannotBuyOwnNFT()
NFTExchange__ArrayLengthMismatch()
NFTExchange__TransferToSellerFailed()

// Auction Errors
Auction__InvalidStartingPrice()
Auction__InvalidDuration()
Auction__AuctionNotActive()
Auction__BidTooLow()
Auction__CannotBidOwnAuction()
Auction__AuctionEnded()
Auction__ReserveNotMet()

// Offer Errors
OfferManager__InvalidOffer()
OfferManager__OfferExpired()
OfferManager__NotOfferCreator()
OfferManager__NotNFTOwner()

// Bundle Errors
BundleManager__InvalidBundle()
BundleManager__BundleNotActive()
BundleManager__InsufficientPayment()
```

## 🔒 Security Considerations

### Before Trading

1. **Always check approvals**
```javascript
const isApproved = await nft.isApprovedForAll(userAddress, exchangeAddress);
if (!isApproved) {
  await nft.setApprovalForAll(exchangeAddress, true);
}
```

2. **Verify contract addresses**
```javascript
// Always verify through hub
const isValidExchange = await hub.isRegisteredExchange(exchangeAddress);
```

3. **Check listing status**
```javascript
const listing = await exchange.getListing(listingId);
if (!listing.isActive || listing.expirationTime < Date.now()/1000) {
  // Listing expired or sold
}
```

## 🛠️ Utility Functions

### Format Prices

```javascript
// Wei to ETH
const ethPrice = ethers.utils.formatEther(weiPrice);

// ETH to Wei
const weiPrice = ethers.utils.parseEther("1.5");
```

### Generate Listing ID

```javascript
// Listing ID is deterministic
const listingId = ethers.utils.keccak256(
  ethers.utils.defaultAbiCoder.encode(
    ["address", "uint256", "address", "uint256"],
    [nftContract, tokenId, seller, timestamp]
  )
);
```

### Check Token Standard

```javascript
// Check if ERC721 or ERC1155
const isERC721 = await hub.getExchangeFor(nftContract) == await hub.getERC721Exchange();
const isERC1155 = !isERC721;
```

## 📈 Gas Optimization Tips

1. **Batch Operations**: Use batch functions when dealing with multiple NFTs
2. **Collection Approvals**: Use `setApprovalForAll` instead of individual approvals
3. **Fee Calculation**: Calculate fees off-chain before transactions
4. **Event Filtering**: Use indexed parameters for efficient event filtering

## 🔄 Migration from Old System

If migrating from direct exchange calls:

**Old way:**
```javascript
// Had to manage multiple exchange addresses
const erc721Exchange = "0x...";
const erc1155Exchange = "0x...";
// Manual detection of which to use
```

**New way:**
```javascript
// Just use hub
const exchange = await hub.getExchangeFor(nftContract);
// Automatic detection!
```

## 📞 Support Functions

### Emergency Controls

```javascript
// Check if system is paused
const isPaused = await emergencyManager.paused();

// Only admin can pause/unpause
await emergencyManager.pause(); // Admin only
await emergencyManager.unpause(); // Admin only
```

### History Tracking

```javascript
const historyTracker = new ethers.Contract(historyAddress, HistoryABI, provider);

// Get user's listing history
const userListings = await historyTracker.getUserListingHistory(userAddress);

// Get collection stats
const stats = await historyTracker.getCollectionStats(collectionAddress);
```

## 🎯 Complete Integration Example

```javascript
// 1. Setup
const hub = new ethers.Contract(MARKETPLACE_HUB, HubABI, signer);
const addresses = await hub.getAllAddresses();

// 2. List NFT
const nft = new ethers.Contract(nftAddress, ERC721ABI, signer);
const exchange = new ethers.Contract(addresses.erc721Exchange, ExchangeABI, signer);

await nft.approve(addresses.erc721Exchange, tokenId);
await exchange.listNFT(nftAddress, tokenId, parseEther("1"), 86400);

// 3. Make offer
const offerManager = new ethers.Contract(addresses.offerManager, OfferABI, signer);
await offerManager.createNFTOffer(nftAddress, tokenId, parseEther("0.8"), 86400, {
  value: parseEther("0.8")
});

// 4. Create bundle
const bundleManager = new ethers.Contract(addresses.bundleManager, BundleABI, signer);
await bundleManager.createBundle(items, parseEther("5"), 86400);

// 5. Start auction
const auctionFactory = new ethers.Contract(addresses.auctionFactory, FactoryABI, signer);
await auctionFactory.createEnglishAuction(
  nftAddress, 
  tokenId, 
  1, 
  parseEther("0.5"),
  parseEther("1"), 
  86400
);
```

## 📚 Additional Resources

- [Contract ABIs](./docs/abis/)
- [TypeScript Types](./docs/types/)
- [Gas Benchmarks](./docs/gas-benchmarks.md)
- [Security Audit](./docs/audit/)

---

**Remember**: The MarketplaceHub is your single entry point. Everything else can be discovered through it!
