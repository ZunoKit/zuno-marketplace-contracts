// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/contracts/errors/MarketplaceAccessControlErrors.sol";
import "src/contracts/events/MarketplaceAccessControlEvents.sol";

/**
 * @title MarketplaceAccessControl
 * @notice Manages role-based access control for the marketplace ecosystem
 * @dev Extends OpenZeppelin's AccessControl with marketplace-specific roles and functions
 * @author NFT Marketplace Team
 */
contract MarketplaceAccessControl is AccessControl, Ownable, ReentrancyGuard {
    // ============================================================================
    // ROLES
    // ============================================================================

    /// @notice Admin role - can manage all other roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Moderator role - can perform emergency actions and moderate content
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    /// @notice Operator role - can update fees and manage operational parameters
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Verifier role - can verify collections and manage verification status
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    /// @notice Emergency role - can perform emergency functions during incidents
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /// @notice Pauser role - can pause/unpause contracts
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    /// @notice Mapping to track role assignment history
    mapping(bytes32 => mapping(address => RoleAssignment[])) public roleHistory;

    /// @notice Mapping to track if a role is currently active
    mapping(bytes32 => bool) public activeRoles;

    /// @notice Mapping to track role permissions
    mapping(bytes32 => RolePermissions) public rolePermissions;

    /// @notice Maximum number of addresses that can have a role simultaneously
    mapping(bytes32 => uint256) public maxRoleMembers;

    /// @notice Current number of members for each role
    mapping(bytes32 => uint256) public currentRoleMembers;

    // ============================================================================
    // STRUCTS
    // ============================================================================

    /**
     * @notice Structure to track role assignment history
     */
    struct RoleAssignment {
        address assignedBy;
        uint256 assignedAt;
        uint256 revokedAt;
        bool isActive;
        string reason;
    }

    // RolePermissions struct is imported from MarketplaceAccessControlEvents.sol

    // ============================================================================
    // EVENTS
    // ============================================================================

    // Events are imported from MarketplaceAccessControlEvents.sol

    // ============================================================================
    // MODIFIERS
    // ============================================================================

    /**
     * @notice Ensures role is active
     */
    modifier onlyActiveRole(bytes32 role) {
        if (!activeRoles[role]) {
            revert MarketplaceAccessControl__RoleNotActive();
        }
        _;
    }

    /**
     * @notice Ensures caller has specific role and role is active
     */
    modifier onlyActiveRoleHolder(bytes32 role) {
        if (!activeRoles[role]) {
            revert MarketplaceAccessControl__RoleNotActive();
        }
        if (!hasRole(role, msg.sender)) {
            revert MarketplaceAccessControl__InsufficientPermissions();
        }
        _;
    }

    /**
     * @notice Ensures role member limit is not exceeded
     */
    modifier withinRoleLimit(bytes32 role) {
        if (currentRoleMembers[role] >= maxRoleMembers[role]) {
            revert MarketplaceAccessControl__RoleMemberLimitExceeded();
        }
        _;
    }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @notice Initializes the access control system
     */
    constructor() Ownable(msg.sender) {
        // Grant admin role to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        // Initialize role settings
        _initializeRoles();
    }

    // ============================================================================
    // ROLE MANAGEMENT FUNCTIONS
    // ============================================================================

    /**
     * @notice Grants a role to an account with reason
     * @param role Role to grant
     * @param account Account to grant role to
     * @param reason Reason for granting the role
     */
    function grantRoleWithReason(bytes32 role, address account, string calldata reason)
        external
        onlyRole(ADMIN_ROLE)
        onlyActiveRole(role)
        withinRoleLimit(role)
        nonReentrant
    {
        if (account == address(0)) {
            revert MarketplaceAccessControl__ZeroAddress();
        }

        if (hasRole(role, account)) {
            revert MarketplaceAccessControl__RoleAlreadyGranted();
        }

        // Grant the role
        _grantRole(role, account);

        // Update role tracking
        currentRoleMembers[role]++;

        // Record role assignment history
        roleHistory[role][account].push(
            RoleAssignment({
                assignedBy: msg.sender,
                assignedAt: block.timestamp,
                revokedAt: 0,
                isActive: true,
                reason: reason
            })
        );

        emit RoleGrantedWithReason(role, account, msg.sender, reason, block.timestamp);
    }

    /**
     * @notice Revokes a role from an account with reason
     * @param role Role to revoke
     * @param account Account to revoke role from
     * @param reason Reason for revoking the role
     */
    function revokeRoleWithReason(bytes32 role, address account, string calldata reason)
        external
        onlyRole(ADMIN_ROLE)
        nonReentrant
    {
        if (!hasRole(role, account)) {
            revert MarketplaceAccessControl__RoleNotGranted();
        }

        // Revoke the role
        _revokeRole(role, account);

        // Update role tracking
        if (currentRoleMembers[role] > 0) {
            currentRoleMembers[role]--;
        }

        // Mark previous active assignments as inactive
        RoleAssignment[] storage assignments = roleHistory[role][account];
        for (uint256 i = 0; i < assignments.length; i++) {
            if (assignments[i].isActive) {
                assignments[i].isActive = false;
                assignments[i].revokedAt = block.timestamp;
            }
        }

        // Add new revocation entry to history
        roleHistory[role][account].push(
            RoleAssignment({
                assignedBy: msg.sender,
                assignedAt: block.timestamp,
                revokedAt: block.timestamp,
                isActive: false,
                reason: reason
            })
        );

        emit RoleRevokedWithReason(role, account, msg.sender, reason, block.timestamp);
    }

    /**
     * @notice Activates or deactivates a role
     * @param role Role to activate/deactivate
     * @param isActive Whether to activate or deactivate
     */
    function setRoleActive(bytes32 role, bool isActive) external onlyRole(ADMIN_ROLE) nonReentrant {
        if (!isActive && (role == DEFAULT_ADMIN_ROLE || role == ADMIN_ROLE)) {
            revert MarketplaceAccessControl__CannotDeactivateAdminRole();
        }

        bool wasActive = activeRoles[role];
        activeRoles[role] = isActive;

        emit RoleStatusChanged(role, wasActive, isActive, msg.sender, block.timestamp);
    }

    /**
     * @notice Sets maximum number of members for a role
     * @param role Role to set limit for
     * @param maxMembers Maximum number of members
     */
    function setRoleMemberLimit(bytes32 role, uint256 maxMembers) external onlyRole(ADMIN_ROLE) nonReentrant {
        if (maxMembers == 0) {
            revert MarketplaceAccessControl__InvalidMemberLimit();
        }

        if (maxMembers < currentRoleMembers[role]) {
            revert MarketplaceAccessControl__MemberLimitBelowCurrent();
        }

        uint256 oldLimit = maxRoleMembers[role];
        maxRoleMembers[role] = maxMembers;

        emit RoleMemberLimitUpdated(role, oldLimit, maxMembers, msg.sender);
    }

    // ============================================================================
    // ROLE PERMISSION FUNCTIONS
    // ============================================================================

    /**
     * @notice Updates permissions for a role
     * @param role Role to update permissions for
     * @param permissions New permissions structure
     */
    function updateRolePermissions(bytes32 role, RolePermissions calldata permissions)
        external
        onlyRole(ADMIN_ROLE)
        nonReentrant
    {
        if (role == DEFAULT_ADMIN_ROLE || role == ADMIN_ROLE) {
            revert MarketplaceAccessControl__CannotModifyAdminPermissions();
        }

        RolePermissions memory oldPermissions = rolePermissions[role];
        rolePermissions[role] = permissions;

        emit RolePermissionsUpdated(role, oldPermissions, permissions, msg.sender);
    }

    /**
     * @notice Checks if an account has specific permission
     * @param account Account to check
     * @param permission Permission to check
     * @return hasPermission Whether account has the permission
     */
    function hasPermission(address account, string calldata permission) external view returns (bool) {
        // Check admin roles first
        if (hasRole(ADMIN_ROLE, account) || hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        }

        // Check specific permissions based on roles
        bytes32 permissionHash = keccak256(abi.encodePacked(permission));

        if (permissionHash == keccak256("EMERGENCY_ACTION")) {
            return hasRole(EMERGENCY_ROLE, account) || hasRole(MODERATOR_ROLE, account);
        } else if (permissionHash == keccak256("UPDATE_FEES")) {
            return hasRole(OPERATOR_ROLE, account);
        } else if (permissionHash == keccak256("VERIFY_COLLECTIONS")) {
            return hasRole(VERIFIER_ROLE, account);
        } else if (permissionHash == keccak256("PAUSE_CONTRACTS")) {
            return hasRole(PAUSER_ROLE, account);
        } else if (permissionHash == keccak256("MODERATE_CONTENT")) {
            return hasRole(MODERATOR_ROLE, account);
        }

        return false;
    }

    // ============================================================================
    // BATCH OPERATIONS
    // ============================================================================

    /**
     * @notice Grants multiple roles to multiple accounts
     * @param roles Array of roles to grant
     * @param accounts Array of accounts to grant roles to
     * @param reasons Array of reasons for each grant
     */
    function batchGrantRoles(bytes32[] calldata roles, address[] calldata accounts, string[] calldata reasons)
        external
        onlyRole(ADMIN_ROLE)
        nonReentrant
    {
        uint256 length = roles.length;
        if (length == 0 || length != accounts.length || length != reasons.length) {
            revert MarketplaceAccessControl__ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < length; i++) {
            if (accounts[i] == address(0)) {
                revert MarketplaceAccessControl__ZeroAddress();
            }

            if (!activeRoles[roles[i]]) {
                revert MarketplaceAccessControl__RoleNotActive();
            }

            if (currentRoleMembers[roles[i]] >= maxRoleMembers[roles[i]]) {
                revert MarketplaceAccessControl__RoleMemberLimitExceeded();
            }

            if (!hasRole(roles[i], accounts[i])) {
                _grantRole(roles[i], accounts[i]);
                currentRoleMembers[roles[i]]++;

                roleHistory[roles[i]][accounts[i]].push(
                    RoleAssignment({
                        assignedBy: msg.sender,
                        assignedAt: block.timestamp,
                        revokedAt: 0,
                        isActive: true,
                        reason: reasons[i]
                    })
                );

                emit RoleGrantedWithReason(roles[i], accounts[i], msg.sender, reasons[i], block.timestamp);
            }
        }

        emit BatchRoleOperationCompleted("GRANT", length, msg.sender, block.timestamp);
    }

    /**
     * @notice Revokes multiple roles from multiple accounts
     * @param roles Array of roles to revoke
     * @param accounts Array of accounts to revoke roles from
     * @param reasons Array of reasons for each revocation
     */
    function batchRevokeRoles(bytes32[] calldata roles, address[] calldata accounts, string[] calldata reasons)
        external
        onlyRole(ADMIN_ROLE)
        nonReentrant
    {
        uint256 length = roles.length;
        if (length == 0 || length != accounts.length || length != reasons.length) {
            revert MarketplaceAccessControl__ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < length; i++) {
            if (hasRole(roles[i], accounts[i])) {
                _revokeRole(roles[i], accounts[i]);

                if (currentRoleMembers[roles[i]] > 0) {
                    currentRoleMembers[roles[i]]--;
                }

                // Mark previous active assignments as inactive
                RoleAssignment[] storage assignments = roleHistory[roles[i]][accounts[i]];
                for (uint256 j = 0; j < assignments.length; j++) {
                    if (assignments[j].isActive) {
                        assignments[j].isActive = false;
                        assignments[j].revokedAt = block.timestamp;
                    }
                }

                // Add new revocation entry to history
                roleHistory[roles[i]][accounts[i]].push(
                    RoleAssignment({
                        assignedBy: msg.sender,
                        assignedAt: block.timestamp,
                        revokedAt: block.timestamp,
                        isActive: false,
                        reason: reasons[i]
                    })
                );

                emit RoleRevokedWithReason(roles[i], accounts[i], msg.sender, reasons[i], block.timestamp);
            }
        }

        emit BatchRoleOperationCompleted("REVOKE", length, msg.sender, block.timestamp);
    }

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    /**
     * @notice Gets role assignment history for an account
     * @param role Role to check
     * @param account Account to check
     * @return assignments Array of role assignments
     */
    function getRoleHistory(bytes32 role, address account)
        external
        view
        returns (RoleAssignment[] memory assignments)
    {
        return roleHistory[role][account];
    }

    /**
     * @notice Gets all active roles for an account
     * @param account Account to check
     * @return activeUserRoles Array of active roles
     */
    function getActiveRoles(address account) external view returns (bytes32[] memory activeUserRoles) {
        bytes32[] memory allRoles = new bytes32[](6);
        allRoles[0] = ADMIN_ROLE;
        allRoles[1] = MODERATOR_ROLE;
        allRoles[2] = OPERATOR_ROLE;
        allRoles[3] = VERIFIER_ROLE;
        allRoles[4] = EMERGENCY_ROLE;
        allRoles[5] = PAUSER_ROLE;

        uint256 activeCount = 0;
        for (uint256 i = 0; i < allRoles.length; i++) {
            if (hasRole(allRoles[i], account)) {
                activeCount++;
            }
        }

        activeUserRoles = new bytes32[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allRoles.length; i++) {
            if (hasRole(allRoles[i], account)) {
                activeUserRoles[index] = allRoles[i];
                index++;
            }
        }

        return activeUserRoles;
    }

    /**
     * @notice Gets role member count and limit
     * @param role Role to check
     * @return current Current number of members
     * @return maximum Maximum allowed members
     */
    function getRoleMemberInfo(bytes32 role) external view returns (uint256 current, uint256 maximum) {
        return (currentRoleMembers[role], maxRoleMembers[role]);
    }

    // ============================================================================
    // INTERNAL FUNCTIONS
    // ============================================================================

    /**
     * @notice Initializes default role settings
     */
    function _initializeRoles() internal {
        // Set all roles as active by default
        activeRoles[DEFAULT_ADMIN_ROLE] = true;
        activeRoles[ADMIN_ROLE] = true;
        activeRoles[MODERATOR_ROLE] = true;
        activeRoles[OPERATOR_ROLE] = true;
        activeRoles[VERIFIER_ROLE] = true;
        activeRoles[EMERGENCY_ROLE] = true;
        activeRoles[PAUSER_ROLE] = true;

        // Set default member limits
        maxRoleMembers[DEFAULT_ADMIN_ROLE] = 3; // Limited DEFAULT_ADMIN_ROLE members
        maxRoleMembers[ADMIN_ROLE] = 5;
        maxRoleMembers[MODERATOR_ROLE] = 10;
        maxRoleMembers[OPERATOR_ROLE] = 15;
        maxRoleMembers[VERIFIER_ROLE] = 20;
        maxRoleMembers[EMERGENCY_ROLE] = 3;
        maxRoleMembers[PAUSER_ROLE] = 5;

        // Initialize current member counts
        currentRoleMembers[DEFAULT_ADMIN_ROLE] = 1; // Deployer
        currentRoleMembers[ADMIN_ROLE] = 1; // Deployer

        // Set default permissions
        _setDefaultPermissions();
    }

    /**
     * @notice Sets default permissions for each role
     */
    function _setDefaultPermissions() internal {
        // Admin permissions (can do everything)
        rolePermissions[ADMIN_ROLE] = RolePermissions({
            canManageRoles: true,
            canEmergencyAction: true,
            canUpdateFees: true,
            canVerifyCollections: true,
            canPauseContracts: true,
            canModerateContent: true,
            canAccessAnalytics: true,
            maxActions: 0, // Unlimited
            cooldownPeriod: 0
        });

        // Moderator permissions
        rolePermissions[MODERATOR_ROLE] = RolePermissions({
            canManageRoles: false,
            canEmergencyAction: true,
            canUpdateFees: false,
            canVerifyCollections: true,
            canPauseContracts: false,
            canModerateContent: true,
            canAccessAnalytics: true,
            maxActions: 100,
            cooldownPeriod: 1 hours
        });

        // Operator permissions
        rolePermissions[OPERATOR_ROLE] = RolePermissions({
            canManageRoles: false,
            canEmergencyAction: false,
            canUpdateFees: true,
            canVerifyCollections: false,
            canPauseContracts: false,
            canModerateContent: false,
            canAccessAnalytics: true,
            maxActions: 50,
            cooldownPeriod: 30 minutes
        });

        // Verifier permissions
        rolePermissions[VERIFIER_ROLE] = RolePermissions({
            canManageRoles: false,
            canEmergencyAction: false,
            canUpdateFees: false,
            canVerifyCollections: true,
            canPauseContracts: false,
            canModerateContent: false,
            canAccessAnalytics: false,
            maxActions: 200,
            cooldownPeriod: 15 minutes
        });

        // Emergency permissions
        rolePermissions[EMERGENCY_ROLE] = RolePermissions({
            canManageRoles: false,
            canEmergencyAction: true,
            canUpdateFees: false,
            canVerifyCollections: false,
            canPauseContracts: true,
            canModerateContent: true,
            canAccessAnalytics: true,
            maxActions: 10,
            cooldownPeriod: 6 hours
        });

        // Pauser permissions
        rolePermissions[PAUSER_ROLE] = RolePermissions({
            canManageRoles: false,
            canEmergencyAction: false,
            canUpdateFees: false,
            canVerifyCollections: false,
            canPauseContracts: true,
            canModerateContent: false,
            canAccessAnalytics: false,
            maxActions: 20,
            cooldownPeriod: 2 hours
        });
    }
}
