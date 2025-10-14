// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title AccessTypes
 * @notice Data structures for access control
 * @dev Types for role-based access and permissions
 */

// ============================================================================
// STRUCTS
// ============================================================================

/**
 * @notice Role assignment tracking
 */
struct RoleAssignment {
    address assignedBy;
    uint256 assignedAt;
    uint256 revokedAt;
    bool isActive;
    string reason;
}

/**
 * @notice Role permissions configuration
 */
struct RolePermissions {
    bool canPause;
    bool canUnpause;
    bool canUpdateFees;
    bool canUpdateRoyalties;
    bool canVerifyCollections;
    bool canManageListings;
    bool canManageAuctions;
    bool canManageOffers;
    bool canManageBundles;
    bool canWithdrawFunds;
    bool canUpdateContracts;
    bool canManageRoles;
}

/**
 * @notice User cooldown tracking
 */
struct UserCooldown {
    uint256 lastListingTime;
    uint256 listingCount;
    bool isRestricted;
}

/**
 * @notice Spam tracking for anti-abuse
 */
struct SpamTracker {
    uint256 actionCount;
    uint256 firstActionTime;
    uint256 lastActionTime;
    bool isFlagged;
}

/**
 * @notice Timelock action data
 */
struct ActionData {
    address target;
    bytes data;
    uint256 value;
    uint256 scheduledTime;
    uint256 executionTime;
    bool executed;
    bool cancelled;
}

// ============================================================================
// CONSTANTS
// ============================================================================

/// @dev Admin role identifier
bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

/// @dev Moderator role identifier
bytes32 constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

/// @dev Operator role identifier
bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

/// @dev Verifier role identifier
bytes32 constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

/// @dev Emergency role identifier
bytes32 constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

/// @dev Pauser role identifier
bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
