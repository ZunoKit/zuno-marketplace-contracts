// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title NFTExchangeEvents
 * @notice Core marketplace events for listings and sales
 * @dev Simple event definitions for basic marketplace operations
 * @dev For detailed auction events, see AuctionEvents.sol
 * @dev For collection events, see CollectionEvents.sol
 */

// ============================================================================
// LISTING EVENTS
// ============================================================================

/**
 * @notice Emitted when an NFT is listed for sale
 * @param listingId Unique identifier for the listing
 * @param contractAddress NFT contract address
 * @param tokenId Token ID being listed
 * @param seller Address of the seller
 * @param price Listing price
 */
event NFTListed(
    bytes32 indexed listingId, address indexed contractAddress, uint256 indexed tokenId, address seller, uint256 price
);

/**
 * @notice Emitted when an NFT is sold
 * @param listingId Unique identifier for the listing
 * @param contractAddress NFT contract address
 * @param tokenId Token ID that was sold
 * @param seller Address of the seller
 * @param buyer Address of the buyer
 * @param price Sale price
 */
event NFTSold(
    bytes32 indexed listingId,
    address indexed contractAddress,
    uint256 indexed tokenId,
    address seller,
    address buyer,
    uint256 price
);

/**
 * @notice Emitted when a listing is cancelled
 * @param listingId Unique identifier for the listing
 * @param contractAddress NFT contract address
 * @param tokenId Token ID that was delisted
 * @param seller Address of the seller
 */
event ListingCancelled(
    bytes32 indexed listingId, address indexed contractAddress, uint256 indexed tokenId, address seller
);

// ============================================================================
// MARKETPLACE CONFIGURATION EVENTS
// ============================================================================

/**
 * @notice Emitted when marketplace wallet address is updated
 * @param oldWallet Previous wallet address
 * @param newWallet New wallet address
 */
event MarketplaceWalletUpdated(address indexed oldWallet, address indexed newWallet);

/**
 * @notice Emitted when taker fee is updated
 * @param oldFee Previous fee amount
 * @param newFee New fee amount
 */
event TakerFeeUpdated(uint256 oldFee, uint256 newFee);

// ============================================================================
// COLLECTION VERIFICATION EVENTS
// ============================================================================

/**
 * @notice Emitted when a collection is verified
 * @param collectionAddress Address of the verified collection
 */
event CollectionVerified(address indexed collectionAddress);

/**
 * @notice Emitted when a collection verification is removed
 * @param collectionAddress Address of the unverified collection
 */
event CollectionUnverified(address indexed collectionAddress);

// ============================================================================
// NOTE: Auction and Collection Creation Events
// ============================================================================
// For comprehensive auction events, use AuctionEvents.sol
// For collection creation events, use CollectionEvents.sol
// These dedicated event files provide more detailed event structures
