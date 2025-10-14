// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title CollectionTypes
 * @notice Data structures for NFT collections
 * @dev Types for collection management and verification
 */

// ============================================================================
// ENUMS
// ============================================================================

/**
 * @notice Collection verification status
 */
enum VerificationStatus {
    UNVERIFIED,
    PENDING,
    VERIFIED,
    REJECTED,
    REVOKED
}

/**
 * @notice Token type for collections
 */
enum TokenType {
    ERC721,
    ERC1155
}

// ============================================================================
// STRUCTS
// ============================================================================

/**
 * @notice Collection verification data
 */
struct CollectionVerification {
    address collection;
    VerificationStatus status;
    uint256 verifiedAt;
    address verifiedBy;
    string verificationProof;
    uint256 trustScore;
    bool hasWarnings;
    string[] warnings;
}

/**
 * @notice Collection metadata
 */
struct CollectionMetadata {
    string name;
    string symbol;
    string description;
    string imageUrl;
    string externalUrl;
    uint256 totalSupply;
    address owner;
    uint256 createdAt;
    TokenType tokenType;
}

/**
 * @notice Verification request
 */
struct VerificationRequest {
    uint256 requestId;
    address requester;
    address collection;
    uint256 requestedAt;
    uint256 fee;
    VerificationStatus status;
    string reason;
    string evidence;
}

/**
 * @notice Collection statistics
 */
struct CollectionStats {
    uint256 totalVolume;
    uint256 totalSales;
    uint256 floorPrice;
    uint256 ceilingPrice;
    uint256 averagePrice;
    uint256 uniqueHolders;
    uint256 totalListings;
    uint256 activeListings;
}
