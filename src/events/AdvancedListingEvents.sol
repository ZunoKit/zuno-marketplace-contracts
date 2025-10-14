// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "src/types/ListingTypes.sol";

/**
 * @title AdvancedListingEvents
 * @notice Events for Advanced Listing system
 * @dev Comprehensive events for all listing operations
 */

// ============================================================================
// LISTING EVENTS
// ============================================================================

/**
 * @notice Emitted when a new listing is created
 * @param listingId Unique identifier for the listing
 * @param listingType Type of listing created
 * @param seller Address of the seller
 * @param nftContract Address of the NFT contract
 * @param tokenId Token ID being listed
 * @param quantity Quantity being listed (for ERC1155)
 * @param price Listing price
 * @param startTime When listing becomes active
 * @param endTime When listing expires
 */
event ListingCreated(
    bytes32 indexed listingId,
    ListingType indexed listingType,
    address indexed seller,
    address nftContract,
    uint256 tokenId,
    uint256 quantity,
    uint256 price,
    uint256 startTime,
    uint256 endTime
);

/**
 * @notice Emitted when a listing is updated
 * @param listingId Listing identifier
 * @param seller Address of the seller
 * @param oldPrice Previous price
 * @param newPrice New price
 * @param oldEndTime Previous end time
 * @param newEndTime New end time
 * @param timestamp When update occurred
 */
event ListingUpdated(
    bytes32 indexed listingId,
    address indexed seller,
    uint256 oldPrice,
    uint256 newPrice,
    uint256 oldEndTime,
    uint256 newEndTime,
    uint256 timestamp
);

/**
 * @notice Emitted when a listing is cancelled
 * @param listingId Listing identifier
 * @param seller Address of the seller
 * @param reason Reason for cancellation
 * @param timestamp When cancellation occurred
 */
event ListingCancelled(bytes32 indexed listingId, address indexed seller, string reason, uint256 timestamp);

/**
 * @notice Emitted when a listing is paused
 * @param listingId Listing identifier
 * @param seller Address of the seller
 * @param reason Reason for pausing
 * @param timestamp When pause occurred
 */
event ListingPaused(bytes32 indexed listingId, address indexed seller, string reason, uint256 timestamp);

/**
 * @notice Emitted when a listing is resumed
 * @param listingId Listing identifier
 * @param seller Address of the seller
 * @param timestamp When resume occurred
 */
event ListingResumed(bytes32 indexed listingId, address indexed seller, uint256 timestamp);

/**
 * @notice Emitted when a listing expires
 * @param listingId Listing identifier
 * @param seller Address of the seller
 * @param timestamp When expiration occurred
 */
event ListingExpired(bytes32 indexed listingId, address indexed seller, uint256 timestamp);

// ============================================================================
// PURCHASE EVENTS
// ============================================================================

/**
 * @notice Emitted when an NFT is purchased
 * @param listingId Listing identifier
 * @param buyer Address of the buyer
 * @param seller Address of the seller
 * @param nftContract Address of the NFT contract
 * @param tokenId Token ID purchased
 * @param quantity Quantity purchased
 * @param price Purchase price
 * @param fees Total fees paid
 * @param timestamp When purchase occurred
 */
event NFTPurchased(
    bytes32 indexed listingId,
    address indexed buyer,
    address indexed seller,
    address nftContract,
    uint256 tokenId,
    uint256 quantity,
    uint256 price,
    uint256 fees,
    uint256 timestamp
);

/**
 * @notice Emitted when a bundle is purchased
 * @param bundleId Bundle identifier
 * @param listingId Associated listing identifier
 * @param buyer Address of the buyer
 * @param seller Address of the seller
 * @param totalPrice Total purchase price
 * @param itemCount Number of items in bundle
 * @param fees Total fees paid
 * @param timestamp When purchase occurred
 */
event BundlePurchased(
    bytes32 indexed bundleId,
    bytes32 indexed listingId,
    address indexed buyer,
    address seller,
    uint256 totalPrice,
    uint256 itemCount,
    uint256 fees,
    uint256 timestamp
);

// ============================================================================
// OFFER EVENTS
// ============================================================================

/**
 * @notice Emitted when an offer is made
 * @param offerId Unique offer identifier
 * @param offerType Type of offer
 * @param listingId Target listing identifier
 * @param buyer Address of the buyer
 * @param seller Address of the seller
 * @param amount Offer amount
 * @param expiry When offer expires
 * @param timestamp When offer was made
 */
event OfferMade(
    bytes32 indexed offerId,
    OfferType indexed offerType,
    bytes32 indexed listingId,
    address buyer,
    address seller,
    uint256 amount,
    uint256 expiry,
    uint256 timestamp
);

/**
 * @notice Emitted when an offer is accepted
 * @param offerId Offer identifier
 * @param listingId Listing identifier
 * @param buyer Address of the buyer
 * @param seller Address of the seller
 * @param amount Accepted amount
 * @param fees Total fees paid
 * @param timestamp When offer was accepted
 */
event OfferAccepted(
    bytes32 indexed offerId,
    bytes32 indexed listingId,
    address indexed buyer,
    address seller,
    uint256 amount,
    uint256 fees,
    uint256 timestamp
);

/**
 * @notice Emitted when an offer is rejected
 * @param offerId Offer identifier
 * @param listingId Listing identifier
 * @param buyer Address of the buyer
 * @param seller Address of the seller
 * @param reason Reason for rejection
 * @param timestamp When offer was rejected
 */
event OfferRejected(
    bytes32 indexed offerId,
    bytes32 indexed listingId,
    address indexed buyer,
    address seller,
    string reason,
    uint256 timestamp
);

/**
 * @notice Emitted when an offer is withdrawn
 * @param offerId Offer identifier
 * @param buyer Address of the buyer
 * @param amount Amount withdrawn
 * @param timestamp When offer was withdrawn
 */
event OfferWithdrawn(bytes32 indexed offerId, address indexed buyer, uint256 amount, uint256 timestamp);

/**
 * @notice Emitted when an offer expires
 * @param offerId Offer identifier
 * @param buyer Address of the buyer
 * @param amount Expired amount
 * @param timestamp When offer expired
 */
event OfferExpired(bytes32 indexed offerId, address indexed buyer, uint256 amount, uint256 timestamp);

// ============================================================================
// AUCTION EVENTS
// ============================================================================

/**
 * @notice Emitted when an auction is created
 * @param listingId Listing identifier
 * @param auctionType Type of auction
 * @param seller Address of the seller
 * @param startingPrice Starting bid price
 * @param reservePrice Reserve price
 * @param duration Auction duration
 * @param timestamp When auction was created
 */
event AuctionCreated(
    bytes32 indexed listingId,
    ListingType indexed auctionType,
    address indexed seller,
    uint256 startingPrice,
    uint256 reservePrice,
    uint256 duration,
    uint256 timestamp
);

/**
 * @notice Emitted when a bid is placed
 * @param listingId Listing identifier
 * @param bidder Address of the bidder
 * @param amount Bid amount
 * @param isHighestBid Whether this is the new highest bid
 * @param timestamp When bid was placed
 */
event BidPlaced(
    bytes32 indexed listingId, address indexed bidder, uint256 amount, bool isHighestBid, uint256 timestamp
);

/**
 * @notice Emitted when an auction is extended
 * @param listingId Listing identifier
 * @param oldEndTime Previous end time
 * @param newEndTime New end time
 * @param extensionReason Reason for extension
 * @param timestamp When extension occurred
 */
event AuctionExtended(
    bytes32 indexed listingId, uint256 oldEndTime, uint256 newEndTime, string extensionReason, uint256 timestamp
);

/**
 * @notice Emitted when an auction ends
 * @param listingId Listing identifier
 * @param winner Address of the winning bidder
 * @param winningBid Final winning bid amount
 * @param totalBids Total number of bids received
 * @param timestamp When auction ended
 */
event AuctionEnded(
    bytes32 indexed listingId, address indexed winner, uint256 winningBid, uint256 totalBids, uint256 timestamp
);

// ============================================================================
// BUNDLE EVENTS
// ============================================================================

/**
 * @notice Emitted when a bundle is created
 * @param bundleId Unique bundle identifier
 * @param creator Address of the bundle creator
 * @param bundleType Type of bundle
 * @param itemCount Number of items in bundle
 * @param totalPrice Total bundle price
 * @param timestamp When bundle was created
 */
event BundleCreated(
    bytes32 indexed bundleId,
    address indexed creator,
    BundleType bundleType,
    uint256 itemCount,
    uint256 totalPrice,
    uint256 timestamp
);

/**
 * @notice Emitted when a bundle is updated
 * @param bundleId Bundle identifier
 * @param creator Address of the bundle creator
 * @param oldPrice Previous total price
 * @param newPrice New total price
 * @param timestamp When bundle was updated
 */
event BundleUpdated(
    bytes32 indexed bundleId, address indexed creator, uint256 oldPrice, uint256 newPrice, uint256 timestamp
);

/**
 * @notice Emitted when a bundle is dissolved
 * @param bundleId Bundle identifier
 * @param creator Address of the bundle creator
 * @param reason Reason for dissolution
 * @param timestamp When bundle was dissolved
 */
event BundleDissolved(bytes32 indexed bundleId, address indexed creator, string reason, uint256 timestamp);

// ============================================================================
// FEE EVENTS
// ============================================================================

/**
 * @notice Emitted when fees are collected
 * @param listingId Associated listing identifier
 * @param feeType Type of fee collected
 * @param amount Fee amount
 * @param recipient Fee recipient
 * @param timestamp When fee was collected
 */
event FeeCollected(
    bytes32 indexed listingId, string feeType, uint256 amount, address indexed recipient, uint256 timestamp
);

/**
 * @notice Emitted when fee structure is updated
 * @param feeType Type of fee updated
 * @param oldFee Previous fee amount/percentage
 * @param newFee New fee amount/percentage
 * @param updatedBy Address that updated the fee
 * @param timestamp When fee was updated
 */
event FeeUpdated(string feeType, uint256 oldFee, uint256 newFee, address indexed updatedBy, uint256 timestamp);

// ============================================================================
// ADMIN EVENTS
// ============================================================================

/**
 * @notice Emitted when contract is paused
 * @param pausedBy Address that paused the contract
 * @param reason Reason for pausing
 * @param timestamp When contract was paused
 */
event ContractPaused(address indexed pausedBy, string reason, uint256 timestamp);

/**
 * @notice Emitted when contract is unpaused
 * @param unpausedBy Address that unpaused the contract
 * @param timestamp When contract was unpaused
 */
event ContractUnpaused(address indexed unpausedBy, uint256 timestamp);

/**
 * @notice Emitted when emergency action is taken
 * @param actionType Type of emergency action
 * @param performedBy Address that performed the action
 * @param target Target of the action
 * @param reason Reason for emergency action
 * @param timestamp When action was performed
 */
event EmergencyAction(
    string actionType, address indexed performedBy, address indexed target, string reason, uint256 timestamp
);

// ============================================================================
// STATISTICS EVENTS
// ============================================================================

/**
 * @notice Emitted when listing statistics are updated
 * @param totalListings Total number of listings
 * @param activeListings Currently active listings
 * @param totalVolume Total volume traded
 * @param averagePrice Average sale price
 * @param timestamp When statistics were updated
 */
event StatisticsUpdated(
    uint256 totalListings, uint256 activeListings, uint256 totalVolume, uint256 averagePrice, uint256 timestamp
);

/**
 * @notice Emitted when user rating is updated
 * @param user Address of the user
 * @param ratingType Type of rating (buyer/seller)
 * @param oldRating Previous rating
 * @param newRating New rating
 * @param ratedBy Address that provided the rating
 * @param timestamp When rating was updated
 */
event UserRatingUpdated(
    address indexed user,
    string ratingType,
    uint256 oldRating,
    uint256 newRating,
    address indexed ratedBy,
    uint256 timestamp
);
