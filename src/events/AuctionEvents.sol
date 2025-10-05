// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title AuctionEvents
 * @notice Contains all events related to auction functionality
 * @dev Centralized event definitions for better organization and maintenance
 */

// ============================================================================
// AUCTION LIFECYCLE EVENTS
// ============================================================================

/**
 * @notice Emitted when a new auction is created
 * @param auctionId Unique identifier for the auction
 * @param nftContract Address of the NFT contract
 * @param tokenId Token ID being auctioned
 * @param seller Address of the seller
 * @param startPrice Starting price of the auction
 * @param reservePrice Minimum price for the auction (0 if no reserve)
 * @param startTime Timestamp when auction starts
 * @param endTime Timestamp when auction ends
 * @param auctionType Type of auction (0=English, 1=Dutch)
 */
event AuctionCreated(
    bytes32 indexed auctionId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    uint256 startPrice,
    uint256 reservePrice,
    uint256 startTime,
    uint256 endTime,
    uint8 auctionType
);

/**
 * @notice Emitted when an auction is cancelled
 * @param auctionId Unique identifier for the auction
 * @param seller Address of the seller who cancelled
 * @param reason Reason for cancellation
 */
event AuctionCancelled(bytes32 indexed auctionId, address indexed seller, string reason);

/**
 * @notice Emitted when an auction is settled
 * @param auctionId Unique identifier for the auction
 * @param winner Address of the auction winner
 * @param finalPrice Final price paid
 * @param seller Address of the seller
 */
event AuctionSettled(bytes32 indexed auctionId, address indexed winner, uint256 finalPrice, address indexed seller);

// ============================================================================
// BIDDING EVENTS
// ============================================================================

/**
 * @notice Emitted when a bid is placed in an English auction
 * @param auctionId Unique identifier for the auction
 * @param bidder Address of the bidder
 * @param bidAmount Amount of the bid
 * @param timestamp Timestamp of the bid
 * @param isWinning Whether this is currently the winning bid
 */
event BidPlaced(
    bytes32 indexed auctionId, address indexed bidder, uint256 bidAmount, uint256 timestamp, bool isWinning
);

/**
 * @notice Emitted when a bid is refunded
 * @param auctionId Unique identifier for the auction
 * @param bidder Address of the bidder receiving refund
 * @param refundAmount Amount being refunded
 */
event BidRefunded(bytes32 indexed auctionId, address indexed bidder, uint256 refundAmount);

/**
 * @notice Emitted when an NFT is purchased in a Dutch auction
 * @param auctionId Unique identifier for the auction
 * @param buyer Address of the buyer
 * @param purchasePrice Price paid for the NFT
 * @param currentPrice Current auction price at time of purchase
 */
event DutchAuctionPurchase(
    bytes32 indexed auctionId, address indexed buyer, uint256 purchasePrice, uint256 currentPrice
);

// ============================================================================
// ADMINISTRATIVE EVENTS
// ============================================================================

/**
 * @notice Emitted when auction factory is paused/unpaused
 * @param isPaused Whether the factory is now paused
 * @param admin Address of the admin who changed the state
 */
event AuctionFactoryPaused(bool isPaused, address indexed admin);

/**
 * @notice Emitted when auction parameters are updated
 * @param auctionId Unique identifier for the auction
 * @param parameter Name of the parameter updated
 * @param oldValue Previous value
 * @param newValue New value
 */
event AuctionParameterUpdated(bytes32 indexed auctionId, string parameter, uint256 oldValue, uint256 newValue);

/**
 * @notice Emitted when auction duration is extended
 * @param auctionId Unique identifier for the auction
 * @param oldEndTime Previous end time
 * @param newEndTime New end time
 * @param reason Reason for extension
 */
event AuctionExtended(bytes32 indexed auctionId, uint256 oldEndTime, uint256 newEndTime, string reason);

// ============================================================================
// FEE AND PAYMENT EVENTS
// ============================================================================

/**
 * @notice Emitted when auction fees are distributed
 * @param auctionId Unique identifier for the auction
 * @param seller Amount paid to seller
 * @param marketplaceFee Amount paid as marketplace fee
 * @param royaltyFee Amount paid as royalty
 * @param royaltyReceiver Address receiving royalty
 */
event AuctionFeesDistributed(
    bytes32 indexed auctionId,
    uint256 seller,
    uint256 marketplaceFee,
    uint256 royaltyFee,
    address indexed royaltyReceiver
);

/**
 * @notice Emitted when emergency withdrawal occurs
 * @param auctionId Unique identifier for the auction
 * @param recipient Address receiving the withdrawal
 * @param amount Amount withdrawn
 * @param reason Reason for emergency withdrawal
 */
event EmergencyWithdrawal(bytes32 indexed auctionId, address indexed recipient, uint256 amount, string reason);
