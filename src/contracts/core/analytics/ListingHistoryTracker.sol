// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "src/contracts/core/access/MarketplaceAccessControl.sol";
import "src/contracts/errors/NFTExchangeErrors.sol";

/**
 * @title ListingHistoryTracker
 * @notice Tracks comprehensive history and analytics for marketplace listings
 * @dev Provides detailed transaction history and price analytics
 * @author NFT Marketplace Team
 */
contract ListingHistoryTracker is Ownable, ReentrancyGuard, Pausable {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    /// @notice Access control contract
    MarketplaceAccessControl public accessControl;

    /// @notice NFT transaction history
    mapping(address => mapping(uint256 => TransactionRecord[])) public nftHistory;

    /// @notice NFT history metadata
    mapping(address => mapping(uint256 => TransactionHistoryMeta)) public nftHistoryMeta;

    /// @notice Collection price statistics
    mapping(address => CollectionStats) public collectionStats;

    /// @notice User trading statistics
    mapping(address => UserStats) public userStats;

    /// @notice Global marketplace statistics
    MarketplaceStats public globalStats;

    /// @notice Price history for collections
    mapping(address => PricePoint[]) public collectionPriceHistory;

    /// @notice Daily trading volumes
    mapping(uint256 => DailyVolume) public dailyVolumes;

    /// @notice Maximum history entries per NFT
    uint256 public constant MAX_HISTORY_ENTRIES = 100;

    /// @notice Maximum price points per collection
    uint256 public constant MAX_PRICE_POINTS = 1000;

    // ============================================================================
    // STRUCTS
    // ============================================================================

    /**
     * @notice Individual transaction record
     */
    struct TransactionRecord {
        bytes32 listingId; // Listing identifier
        address seller; // Seller address
        address buyer; // Buyer address (zero for listings)
        uint256 price; // Transaction price
        uint256 timestamp; // Transaction timestamp
        TransactionType txType; // Type of transaction
        uint8 listingType; // Type of listing (0=FIXED_PRICE, 1=AUCTION, etc.)
        bool isActive; // Whether transaction is active
    }

    /**
     * @notice Transaction history metadata for an NFT
     */
    struct TransactionHistoryMeta {
        uint256 totalTransactions; // Total number of transactions
        uint256 totalVolume; // Total trading volume
        uint256 lastSalePrice; // Last sale price
        uint256 lastSaleTime; // Last sale timestamp
        address currentOwner; // Current owner
    }

    /**
     * @notice Collection statistics
     */
    struct CollectionStats {
        uint256 totalListings; // Total listings created
        uint256 totalSales; // Total completed sales
        uint256 totalVolume; // Total trading volume
        uint256 floorPrice; // Current floor price
        uint256 averagePrice; // Average sale price
        uint256 highestSale; // Highest sale price
        uint256 activeListings; // Current active listings
        uint256 lastUpdated; // Last update timestamp
    }

    /**
     * @notice User trading statistics
     */
    struct UserStats {
        uint256 totalListings; // Total listings created
        uint256 totalSales; // Total sales completed
        uint256 totalPurchases; // Total purchases made
        uint256 volumeSold; // Total volume sold
        uint256 volumeBought; // Total volume bought
        uint256 averageSalePrice; // Average sale price
        uint256 averagePurchasePrice; // Average purchase price
        uint256 firstActivity; // First activity timestamp
        uint256 lastActivity; // Last activity timestamp
    }

    /**
     * @notice Global marketplace statistics
     */
    struct MarketplaceStats {
        uint256 totalListings; // Total listings ever created
        uint256 totalSales; // Total sales completed
        uint256 totalVolume; // Total trading volume
        uint256 totalUsers; // Total unique users
        uint256 totalCollections; // Total collections with activity
        uint256 averageSalePrice; // Global average sale price
        uint256 dailyActiveUsers; // Daily active users
        uint256 lastUpdated; // Last update timestamp
    }

    /**
     * @notice Price point for historical tracking
     */
    struct PricePoint {
        uint256 price; // Price at this point
        uint256 timestamp; // Timestamp of price point
        uint256 volume; // Volume at this price
        TransactionType source; // Source of price point
    }

    /**
     * @notice Daily trading volume
     */
    struct DailyVolume {
        uint256 volume; // Total volume for the day
        uint256 transactions; // Number of transactions
        uint256 uniqueUsers; // Unique users active
        uint256 averagePrice; // Average price for the day
    }

    /**
     * @notice Transaction types
     */
    enum TransactionType {
        LISTING_CREATED,
        LISTING_UPDATED,
        LISTING_CANCELLED,
        SALE_COMPLETED,
        OFFER_MADE,
        OFFER_ACCEPTED,
        AUCTION_BID,
        AUCTION_WON
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    event TransactionRecorded(
        address indexed collection,
        uint256 indexed tokenId,
        bytes32 indexed listingId,
        TransactionType txType,
        address user,
        uint256 price
    );

    event CollectionStatsUpdated(
        address indexed collection, uint256 totalVolume, uint256 floorPrice, uint256 averagePrice
    );

    event UserStatsUpdated(address indexed user, uint256 totalSales, uint256 totalPurchases, uint256 volumeTraded);

    event PricePointAdded(address indexed collection, uint256 price, uint256 timestamp, TransactionType source);

    // ============================================================================
    // MODIFIERS
    // ============================================================================

    /**
     * @notice Ensures caller has required role
     */
    modifier onlyRole(bytes32 role) {
        if (!accessControl.hasRole(role, msg.sender)) {
            revert NFTExchange__NotTheOwner();
        }
        _;
    }

    /**
     * @notice Validates collection and token
     */
    modifier validNFT(address collection, uint256 tokenId) {
        if (collection == address(0)) {
            revert NFTExchange__InvalidMarketplaceWallet();
        }
        _;
    }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @notice Initializes the ListingHistoryTracker
     * @param _accessControl Address of the access control contract
     */
    constructor(address _accessControl) Ownable(msg.sender) {
        if (_accessControl == address(0)) {
            revert NFTExchange__NotTheOwner();
        }

        accessControl = MarketplaceAccessControl(_accessControl);

        // Initialize global stats
        globalStats = MarketplaceStats({
            totalListings: 0,
            totalSales: 0,
            totalVolume: 0,
            totalUsers: 0,
            totalCollections: 0,
            averageSalePrice: 0,
            dailyActiveUsers: 0,
            lastUpdated: block.timestamp
        });
    }

    // ============================================================================
    // TRACKING FUNCTIONS
    // ============================================================================

    /**
     * @notice Records a new transaction
     * @param collection Collection address
     * @param tokenId Token ID
     * @param listingId Listing identifier
     * @param txType Type of transaction
     * @param user User involved in transaction
     * @param price Transaction price
     */
    function recordTransaction(
        address collection,
        uint256 tokenId,
        bytes32 listingId,
        TransactionType txType,
        address user,
        uint256 price
    ) external onlyRole(accessControl.OPERATOR_ROLE()) validNFT(collection, tokenId) {
        // Create transaction record
        TransactionRecord memory record = TransactionRecord({
            listingId: listingId,
            seller: txType == TransactionType.SALE_COMPLETED ? user : address(0),
            buyer: txType == TransactionType.SALE_COMPLETED ? msg.sender : address(0),
            price: price,
            timestamp: block.timestamp,
            txType: txType,
            listingType: 0, // Default FIXED_PRICE, should be passed as parameter
            isActive: true
        });

        // Add to NFT history
        _addToNFTHistory(collection, tokenId, record);

        // Update statistics
        _updateCollectionStats(collection, txType, price);
        _updateUserStats(user, txType, price);
        _updateGlobalStats(txType, price);

        // Add price point for sales
        if (txType == TransactionType.SALE_COMPLETED) {
            _addPricePoint(collection, price, txType);
        }

        // Update daily volume
        _updateDailyVolume(price, txType);

        emit TransactionRecorded(collection, tokenId, listingId, txType, user, price);
    }

    /**
     * @notice Gets transaction history for an NFT
     * @param collection Collection address
     * @param tokenId Token ID
     * @param limit Maximum number of records to return
     * @return records Array of transaction records
     */
    function getNFTHistory(address collection, uint256 tokenId, uint256 limit)
        external
        view
        validNFT(collection, tokenId)
        returns (TransactionRecord[] memory records)
    {
        TransactionRecord[] memory allTransactions = nftHistory[collection][tokenId];
        uint256 recordCount = allTransactions.length;

        if (limit > 0 && limit < recordCount) {
            recordCount = limit;
        }

        records = new TransactionRecord[](recordCount);

        // Return most recent transactions first
        for (uint256 i = 0; i < recordCount; i++) {
            records[i] = allTransactions[allTransactions.length - 1 - i];
        }

        return records;
    }

    /**
     * @notice Gets price history for a collection
     * @param collection Collection address
     * @param limit Maximum number of price points
     * @return pricePoints Array of price points
     */
    function getCollectionPriceHistory(address collection, uint256 limit)
        external
        view
        returns (PricePoint[] memory pricePoints)
    {
        PricePoint[] memory allPoints = collectionPriceHistory[collection];
        uint256 pointCount = allPoints.length;

        if (limit > 0 && limit < pointCount) {
            pointCount = limit;
        }

        pricePoints = new PricePoint[](pointCount);

        // Return most recent points first
        for (uint256 i = 0; i < pointCount; i++) {
            pricePoints[i] = allPoints[allPoints.length - 1 - i];
        }

        return pricePoints;
    }

    // ============================================================================
    // INTERNAL FUNCTIONS
    // ============================================================================

    /**
     * @notice Adds transaction to NFT history
     */
    function _addToNFTHistory(address collection, uint256 tokenId, TransactionRecord memory record) internal {
        TransactionRecord[] storage transactions = nftHistory[collection][tokenId];
        TransactionHistoryMeta storage meta = nftHistoryMeta[collection][tokenId];

        // Limit history size
        if (transactions.length >= MAX_HISTORY_ENTRIES) {
            // Remove oldest transaction
            for (uint256 i = 0; i < transactions.length - 1; i++) {
                transactions[i] = transactions[i + 1];
            }
            transactions[transactions.length - 1] = record;
        } else {
            transactions.push(record);
        }

        // Update history metadata
        meta.totalTransactions++;

        if (record.txType == TransactionType.SALE_COMPLETED) {
            meta.totalVolume += record.price;
            meta.lastSalePrice = record.price;
            meta.lastSaleTime = record.timestamp;
        }
    }

    /**
     * @notice Updates collection statistics
     */
    function _updateCollectionStats(address collection, TransactionType txType, uint256 price) internal {
        CollectionStats storage stats = collectionStats[collection];

        if (txType == TransactionType.LISTING_CREATED) {
            stats.totalListings++;
            stats.activeListings++;
        } else if (txType == TransactionType.SALE_COMPLETED) {
            stats.totalSales++;
            stats.totalVolume += price;
            stats.activeListings = stats.activeListings > 0 ? stats.activeListings - 1 : 0;

            // Update average price
            stats.averagePrice = stats.totalVolume / stats.totalSales;

            // Update highest sale
            if (price > stats.highestSale) {
                stats.highestSale = price;
            }
        } else if (txType == TransactionType.LISTING_CANCELLED) {
            stats.activeListings = stats.activeListings > 0 ? stats.activeListings - 1 : 0;
        }

        stats.lastUpdated = block.timestamp;

        emit CollectionStatsUpdated(collection, stats.totalVolume, stats.floorPrice, stats.averagePrice);
    }

    /**
     * @notice Updates user statistics
     */
    function _updateUserStats(address user, TransactionType txType, uint256 price) internal {
        UserStats storage stats = userStats[user];

        if (stats.firstActivity == 0) {
            stats.firstActivity = block.timestamp;
        }

        stats.lastActivity = block.timestamp;

        if (txType == TransactionType.LISTING_CREATED) {
            stats.totalListings++;
        } else if (txType == TransactionType.SALE_COMPLETED) {
            stats.totalSales++;
            stats.volumeSold += price;

            // Update average sale price
            stats.averageSalePrice = stats.volumeSold / stats.totalSales;
        }

        emit UserStatsUpdated(user, stats.totalSales, stats.totalPurchases, stats.volumeSold + stats.volumeBought);
    }

    /**
     * @notice Updates global marketplace statistics
     */
    function _updateGlobalStats(TransactionType txType, uint256 price) internal {
        if (txType == TransactionType.LISTING_CREATED) {
            globalStats.totalListings++;
        } else if (txType == TransactionType.SALE_COMPLETED) {
            globalStats.totalSales++;
            globalStats.totalVolume += price;

            // Update average price
            globalStats.averageSalePrice = globalStats.totalVolume / globalStats.totalSales;
        }

        globalStats.lastUpdated = block.timestamp;
    }

    /**
     * @notice Adds price point to collection history
     */
    function _addPricePoint(address collection, uint256 price, TransactionType source) internal {
        PricePoint[] storage pricePoints = collectionPriceHistory[collection];

        // Limit price points
        if (pricePoints.length >= MAX_PRICE_POINTS) {
            // Remove oldest point
            for (uint256 i = 0; i < pricePoints.length - 1; i++) {
                pricePoints[i] = pricePoints[i + 1];
            }
            pricePoints[pricePoints.length - 1] =
                PricePoint({price: price, timestamp: block.timestamp, volume: price, source: source});
        } else {
            pricePoints.push(PricePoint({price: price, timestamp: block.timestamp, volume: price, source: source}));
        }

        emit PricePointAdded(collection, price, block.timestamp, source);
    }

    /**
     * @notice Updates daily trading volume
     */
    function _updateDailyVolume(uint256 price, TransactionType txType) internal {
        uint256 today = block.timestamp / 1 days;
        DailyVolume storage volume = dailyVolumes[today];

        if (txType == TransactionType.SALE_COMPLETED) {
            volume.volume += price;
            volume.transactions++;

            // Update average price
            volume.averagePrice = volume.volume / volume.transactions;
        }
    }
}
