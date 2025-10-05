// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title MarketplaceAccessControlErrors
 * @notice Custom errors for MarketplaceAccessControl contract
 * @dev Using custom errors instead of require strings for gas optimization
 */

// ============================================================================
// GENERAL ERRORS
// ============================================================================

/// @notice Thrown when a zero address is provided where not allowed
error MarketplaceAccessControl__ZeroAddress();

/// @notice Thrown when array lengths don't match in batch operations
error MarketplaceAccessControl__ArrayLengthMismatch();

/// @notice Thrown when an empty array is provided
error MarketplaceAccessControl__EmptyArray();

/// @notice Thrown when caller doesn't have sufficient permissions
error MarketplaceAccessControl__InsufficientPermissions();

/// @notice Thrown when an invalid parameter is provided
error MarketplaceAccessControl__InvalidParameter();

// ============================================================================
// ROLE MANAGEMENT ERRORS
// ============================================================================

/// @notice Thrown when trying to use an inactive role
error MarketplaceAccessControl__RoleNotActive();

/// @notice Thrown when trying to grant a role that's already granted
error MarketplaceAccessControl__RoleAlreadyGranted();

/// @notice Thrown when trying to revoke a role that's not granted
error MarketplaceAccessControl__RoleNotGranted();

/// @notice Thrown when role member limit is exceeded
error MarketplaceAccessControl__RoleMemberLimitExceeded();

/// @notice Thrown when trying to set member limit below current count
error MarketplaceAccessControl__MemberLimitBelowCurrent();

/// @notice Thrown when trying to set invalid member limit (0)
error MarketplaceAccessControl__InvalidMemberLimit();

/// @notice Thrown when trying to deactivate admin role
error MarketplaceAccessControl__CannotDeactivateAdminRole();

/// @notice Thrown when trying to modify admin role permissions
error MarketplaceAccessControl__CannotModifyAdminPermissions();

// ============================================================================
// PERMISSION ERRORS
// ============================================================================

/// @notice Thrown when trying to access a function without required role
error MarketplaceAccessControl__MissingRole(bytes32 role);

/// @notice Thrown when trying to perform action without specific permission
error MarketplaceAccessControl__MissingPermission(string permission);

/// @notice Thrown when action limit is exceeded for a role
error MarketplaceAccessControl__ActionLimitExceeded();

/// @notice Thrown when action is performed during cooldown period
error MarketplaceAccessControl__CooldownActive();

/// @notice Thrown when trying to grant permission that doesn't exist
error MarketplaceAccessControl__InvalidPermission();

// ============================================================================
// BATCH OPERATION ERRORS
// ============================================================================

/// @notice Thrown when batch operation partially fails
error MarketplaceAccessControl__BatchOperationPartialFailure();

/// @notice Thrown when batch operation completely fails
error MarketplaceAccessControl__BatchOperationFailed();

/// @notice Thrown when batch size exceeds maximum allowed
error MarketplaceAccessControl__BatchSizeExceeded();

// ============================================================================
// ROLE HIERARCHY ERRORS
// ============================================================================

/// @notice Thrown when trying to grant role to higher hierarchy level
error MarketplaceAccessControl__InvalidRoleHierarchy();

/// @notice Thrown when trying to revoke role from higher authority
error MarketplaceAccessControl__CannotRevokeHigherAuthority();

/// @notice Thrown when role dependency is not met
error MarketplaceAccessControl__RoleDependencyNotMet();

// ============================================================================
// EMERGENCY ERRORS
// ============================================================================

/// @notice Thrown when emergency action is not allowed in current state
error MarketplaceAccessControl__EmergencyActionNotAllowed();

/// @notice Thrown when emergency role is required but not held
error MarketplaceAccessControl__EmergencyRoleRequired();

/// @notice Thrown when emergency cooldown is active
error MarketplaceAccessControl__EmergencyCooldownActive();

// ============================================================================
// CONFIGURATION ERRORS
// ============================================================================

/// @notice Thrown when trying to set invalid configuration
error MarketplaceAccessControl__InvalidConfiguration();

/// @notice Thrown when configuration change is not allowed
error MarketplaceAccessControl__ConfigurationChangeNotAllowed();

/// @notice Thrown when configuration value is out of bounds
error MarketplaceAccessControl__ConfigurationOutOfBounds();

// ============================================================================
// AUDIT ERRORS
// ============================================================================

/// @notice Thrown when audit trail is corrupted or invalid
error MarketplaceAccessControl__InvalidAuditTrail();

/// @notice Thrown when trying to access restricted audit information
error MarketplaceAccessControl__AuditAccessRestricted();

/// @notice Thrown when audit log is full
error MarketplaceAccessControl__AuditLogFull();

// ============================================================================
// TIME-BASED ERRORS
// ============================================================================

/// @notice Thrown when action is performed outside allowed time window
error MarketplaceAccessControl__OutsideTimeWindow();

/// @notice Thrown when role assignment has expired
error MarketplaceAccessControl__RoleAssignmentExpired();

/// @notice Thrown when trying to extend role beyond maximum duration
error MarketplaceAccessControl__MaxRoleDurationExceeded();

// ============================================================================
// MULTI-SIG ERRORS
// ============================================================================

/// @notice Thrown when multi-signature requirement is not met
error MarketplaceAccessControl__MultiSigRequirementNotMet();

/// @notice Thrown when trying to approve own multi-sig proposal
error MarketplaceAccessControl__CannotApproveSelfProposal();

/// @notice Thrown when multi-sig proposal has expired
error MarketplaceAccessControl__MultiSigProposalExpired();

// ============================================================================
// DELEGATION ERRORS
// ============================================================================

/// @notice Thrown when delegation is not allowed for the role
error MarketplaceAccessControl__DelegationNotAllowed();

/// @notice Thrown when trying to delegate to invalid address
error MarketplaceAccessControl__InvalidDelegationTarget();

/// @notice Thrown when delegation chain is too long
error MarketplaceAccessControl__DelegationChainTooLong();

/// @notice Thrown when trying to delegate already delegated role
error MarketplaceAccessControl__RoleAlreadyDelegated();

// ============================================================================
// SUSPENSION ERRORS
// ============================================================================

/// @notice Thrown when trying to use suspended role
error MarketplaceAccessControl__RoleSuspended();

/// @notice Thrown when trying to suspend role that cannot be suspended
error MarketplaceAccessControl__RoleCannotBeSuspended();

/// @notice Thrown when suspension period is invalid
error MarketplaceAccessControl__InvalidSuspensionPeriod();
