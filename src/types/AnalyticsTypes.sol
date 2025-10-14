// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title AnalyticsTypes
 * @notice Data structures for marketplace analytics
 * @dev Types for tracking and reporting
 */

// ============================================================================
// ENUMS
// ============================================================================

/**
 * @notice Types of marketplace transactions
 */
enum TransactionType {
    LISTING_CREATED,
    LISTING_SOLD,
    LISTING_CANCELLED,
    OFFER_MADE,
    OFFER_ACCEPTED,
    OFFER_REJECTED,
    AUCTION_STARTED,
    AUCTION_BID,
    AUCTION_ENDED,
    BUNDLE_CREATED,
    BUNDLE_SOLD
}

// ============================================================================
// STRUCTS
// ============================================================================

/**
 * @notice Transaction record for history tracking
 */
struct TransactionRecord {
    bytes32 transactionId;
    TransactionType txType;
    address initiator;
    address counterparty;
    address nftContract;
    uint256 tokenId;
    uint256 amount;
    uint256 price;
    uint256 timestamp;
    bytes32 referenceId;
}

/**
 * @notice Transaction history metadata
 */
struct TransactionHistoryMeta {
    uint256 totalCount;
    uint256 firstTransaction;
    uint256 lastTransaction;
    uint256 totalVolume;
}

/**
 * @notice User statistics
 */
struct UserStats {
    uint256 totalListings;
    uint256 successfulSales;
    uint256 totalPurchases;
    uint256 totalSpent;
    uint256 totalEarned;
    uint256 totalOffersMade;
    uint256 totalOffersReceived;
    uint256 averageSalePrice;
    uint256 averagePurchasePrice;
    uint256 rating;
    uint256 totalRatings;
}

/**
 * @notice Marketplace statistics
 */
struct MarketplaceStats {
    uint256 totalListings;
    uint256 activeListings;
    uint256 totalVolume;
    uint256 totalTransactions;
    uint256 uniqueUsers;
    uint256 uniqueCollections;
    uint256 totalFeeCollected;
    uint256 averageTransactionValue;
    uint256 last24HVolume;
    uint256 last7DaysVolume;
}

/**
 * @notice Price history point
 */
struct PricePoint {
    uint256 price;
    uint256 timestamp;
    uint256 volume;
    address collection;
}

/**
 * @notice Daily volume tracking
 */
struct DailyVolume {
    uint256 date;
    uint256 volume;
    uint256 transactionCount;
    uint256 uniqueUsers;
}
