// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ExchangeTypes
 * @notice Data structures for NFT exchange
 * @dev Core types for marketplace exchange functionality
 */

// ============================================================================
// ENUMS
// ============================================================================

/**
 * @notice Token standards supported
 */
enum TokenStandard {
    ERC721,
    ERC1155,
    UNKNOWN
}

/**
 * @notice Exchange types
 */
enum ExchangeType {
    ERC721_EXCHANGE,
    ERC1155_EXCHANGE
}

/**
 * @notice NFT validation status
 */
enum NFTStatus {
    INVALID,
    NOT_APPROVED,
    NOT_OWNER,
    VALID
}

// ============================================================================
// STRUCTS
// ============================================================================

/**
 * @notice Exchange information
 */
struct ExchangeInfo {
    address exchangeAddress;
    ExchangeType exchangeType;
    bool isActive;
    uint256 totalVolume;
    uint256 totalTransactions;
}

/**
 * @notice Listing data for exchanges
 */
struct ListingData {
    bytes32 listingId;
    address seller;
    address contractAddress;
    uint256 tokenId;
    uint256 price;
    uint256 amount;
    uint256 listingTime;
    uint256 expirationTime;
    bool isActive;
}

/**
 * @notice Batch purchase data
 */
struct BatchPurchaseData {
    bytes32[] listingIds;
    address buyer;
    uint256 totalPrice;
    uint256 totalFees;
    uint256 totalRoyalties;
}

/**
 * @notice NFT validation parameters
 */
struct ValidationParams {
    address nftContract;
    uint256 tokenId;
    uint256 amount;
    address owner;
    address spender;
}

/**
 * @notice Validation result
 */
struct ValidationResult {
    bool isValid;
    string errorMessage;
    NFTStatus status;
}

/**
 * @notice Transfer parameters
 */
struct TransferParams {
    address nftContract;
    uint256 tokenId;
    uint256 amount;
    address from;
    address to;
    TokenStandard standard;
}

/**
 * @notice Batch transfer parameters
 */
struct BatchTransferParams {
    address nftContract;
    uint256[] tokenIds;
    uint256[] amounts;
    address from;
    address to;
    TokenStandard standard;
}

/**
 * @notice Transfer result
 */
struct TransferResult {
    bool success;
    string errorMessage;
    uint256 transferredCount;
}

/**
 * @notice Batch listing parameters
 */
struct BatchListingParams {
    address nftContract;
    uint256[] tokenIds;
    uint256[] amounts;
    uint256[] prices;
    uint256 listingDuration;
    address seller;
    address spender;
}

/**
 * @notice Batch purchase parameters
 */
struct BatchPurchaseParams {
    bytes32[] listingIds;
    address buyer;
    uint256 expectedTotalPrice;
}

/**
 * @notice Purchase calculation result
 */
struct PurchaseCalculation {
    uint256 totalListingPrice;
    uint256 totalFees;
    uint256 totalRoyalties;
    uint256 totalBuyerCost;
}
