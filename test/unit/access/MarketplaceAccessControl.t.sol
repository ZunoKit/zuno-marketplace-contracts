// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {MarketplaceAccessControl} from "src/core/access/MarketplaceAccessControl.sol";
import "src/errors/MarketplaceAccessControlErrors.sol";
import "src/events/MarketplaceAccessControlEvents.sol";

/**
 * @title MarketplaceAccessControlTest
 * @notice Comprehensive unit tests for MarketplaceAccessControl contract
 * @dev Tests all role management, permissions, and access control features
 */
contract MarketplaceAccessControlTest is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    MarketplaceAccessControl public accessControl;

    address public owner;
    address public admin1;
    address public admin2;
    address public moderator1;
    address public moderator2;
    address public operator1;
    address public verifier1;
    address public emergency1;
    address public pauser1;
    address public user1;
    address public user2;

    // Role constants
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        // Setup test accounts
        owner = makeAddr("owner");
        admin1 = makeAddr("admin1");
        admin2 = makeAddr("admin2");
        moderator1 = makeAddr("moderator1");
        moderator2 = makeAddr("moderator2");
        operator1 = makeAddr("operator1");
        verifier1 = makeAddr("verifier1");
        emergency1 = makeAddr("emergency1");
        pauser1 = makeAddr("pauser1");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy as owner
        vm.startPrank(owner);
        accessControl = new MarketplaceAccessControl();
        vm.stopPrank();
    }

    // ============================================================================
    // CONSTRUCTOR TESTS
    // ============================================================================

    function test_Constructor_Success() public {
        assertEq(accessControl.owner(), owner);
        assertTrue(accessControl.hasRole(accessControl.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(accessControl.hasRole(ADMIN_ROLE, owner));

        // Check role initialization
        assertTrue(accessControl.activeRoles(ADMIN_ROLE));
        assertTrue(accessControl.activeRoles(MODERATOR_ROLE));
        assertTrue(accessControl.activeRoles(OPERATOR_ROLE));
        assertTrue(accessControl.activeRoles(VERIFIER_ROLE));
        assertTrue(accessControl.activeRoles(EMERGENCY_ROLE));
        assertTrue(accessControl.activeRoles(PAUSER_ROLE));

        // Check member limits
        (uint256 current, uint256 maximum) = accessControl.getRoleMemberInfo(ADMIN_ROLE);
        assertEq(current, 1);
        assertEq(maximum, 5);
    }

    // ============================================================================
    // ROLE GRANTING TESTS
    // ============================================================================

    function test_GrantRoleWithReason_Success() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit RoleGrantedWithReason(MODERATOR_ROLE, moderator1, owner, "Initial moderator", block.timestamp);

        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Initial moderator");

        assertTrue(accessControl.hasRole(MODERATOR_ROLE, moderator1));

        (uint256 current,) = accessControl.getRoleMemberInfo(MODERATOR_ROLE);
        assertEq(current, 1);
    }

    function test_GrantRoleWithReason_RevertNotAdmin() public {
        vm.startPrank(user1);

        vm.expectRevert();
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Unauthorized attempt");
    }

    function test_GrantRoleWithReason_RevertZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert(MarketplaceAccessControl__ZeroAddress.selector);
        accessControl.grantRoleWithReason(MODERATOR_ROLE, address(0), "Invalid address");
    }

    function test_GrantRoleWithReason_RevertRoleAlreadyGranted() public {
        vm.startPrank(owner);

        // Grant role first time
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Initial grant");

        // Try to grant again
        vm.expectRevert(MarketplaceAccessControl__RoleAlreadyGranted.selector);
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Duplicate grant");
    }

    function test_GrantRoleWithReason_RevertInactiveRole() public {
        vm.startPrank(owner);

        // Deactivate role first
        accessControl.setRoleActive(MODERATOR_ROLE, false);

        vm.expectRevert(MarketplaceAccessControl__RoleNotActive.selector);
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Inactive role");
    }

    function test_GrantRoleWithReason_RevertMemberLimitExceeded() public {
        vm.startPrank(owner);

        // Set low limit for testing
        accessControl.setRoleMemberLimit(MODERATOR_ROLE, 1);

        // Grant to first user
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "First moderator");

        // Try to grant to second user (should fail)
        vm.expectRevert(MarketplaceAccessControl__RoleMemberLimitExceeded.selector);
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator2, "Second moderator");
    }

    // ============================================================================
    // ROLE REVOKING TESTS
    // ============================================================================

    function test_RevokeRoleWithReason_Success() public {
        vm.startPrank(owner);

        // Grant role first
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Initial grant");
        assertTrue(accessControl.hasRole(MODERATOR_ROLE, moderator1));

        // Revoke role
        vm.expectEmit(true, true, true, true);
        emit RoleRevokedWithReason(MODERATOR_ROLE, moderator1, owner, "No longer needed", block.timestamp);

        accessControl.revokeRoleWithReason(MODERATOR_ROLE, moderator1, "No longer needed");

        assertFalse(accessControl.hasRole(MODERATOR_ROLE, moderator1));

        (uint256 current,) = accessControl.getRoleMemberInfo(MODERATOR_ROLE);
        assertEq(current, 0);
    }

    function test_RevokeRoleWithReason_RevertNotGranted() public {
        vm.startPrank(owner);

        vm.expectRevert(MarketplaceAccessControl__RoleNotGranted.selector);
        accessControl.revokeRoleWithReason(MODERATOR_ROLE, moderator1, "Role not granted");
    }

    function test_RevokeRoleWithReason_RevertNotAdmin() public {
        vm.startPrank(owner);
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Initial grant");
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        accessControl.revokeRoleWithReason(MODERATOR_ROLE, moderator1, "Unauthorized");
    }

    // ============================================================================
    // ROLE STATUS TESTS
    // ============================================================================

    function test_SetRoleActive_Success() public {
        vm.startPrank(owner);

        assertTrue(accessControl.activeRoles(MODERATOR_ROLE));

        vm.expectEmit(true, false, false, true);
        emit RoleStatusChanged(MODERATOR_ROLE, true, false, owner, block.timestamp);

        accessControl.setRoleActive(MODERATOR_ROLE, false);

        assertFalse(accessControl.activeRoles(MODERATOR_ROLE));
    }

    function test_SetRoleActive_RevertCannotDeactivateAdmin() public {
        vm.startPrank(owner);

        // Test ADMIN_ROLE deactivation (should revert)
        vm.expectRevert(MarketplaceAccessControl__CannotDeactivateAdminRole.selector);
        accessControl.setRoleActive(ADMIN_ROLE, false);

        // Test DEFAULT_ADMIN_ROLE deactivation (should revert)
        bytes32 defaultAdminRole = accessControl.DEFAULT_ADMIN_ROLE();
        vm.expectRevert(MarketplaceAccessControl__CannotDeactivateAdminRole.selector);
        accessControl.setRoleActive(defaultAdminRole, false);

        vm.stopPrank();
    }

    function test_SetRoleActive_RevertNotAdmin() public {
        vm.startPrank(user1);

        vm.expectRevert();
        accessControl.setRoleActive(MODERATOR_ROLE, false);
    }

    // ============================================================================
    // ROLE MEMBER LIMIT TESTS
    // ============================================================================

    function test_SetRoleMemberLimit_Success() public {
        vm.startPrank(owner);

        (uint256 currentBefore, uint256 maxBefore) = accessControl.getRoleMemberInfo(MODERATOR_ROLE);
        assertEq(maxBefore, 10); // Default limit

        vm.expectEmit(true, false, false, true);
        emit RoleMemberLimitUpdated(MODERATOR_ROLE, 10, 20, owner);

        accessControl.setRoleMemberLimit(MODERATOR_ROLE, 20);

        (, uint256 maxAfter) = accessControl.getRoleMemberInfo(MODERATOR_ROLE);
        assertEq(maxAfter, 20);
    }

    function test_SetRoleMemberLimit_RevertZeroLimit() public {
        vm.startPrank(owner);

        vm.expectRevert(MarketplaceAccessControl__InvalidMemberLimit.selector);
        accessControl.setRoleMemberLimit(MODERATOR_ROLE, 0);
    }

    function test_SetRoleMemberLimit_RevertBelowCurrent() public {
        vm.startPrank(owner);

        // Grant roles to 3 users
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Test 1");
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator2, "Test 2");
        accessControl.grantRoleWithReason(MODERATOR_ROLE, user1, "Test 3");

        (uint256 current,) = accessControl.getRoleMemberInfo(MODERATOR_ROLE);
        assertEq(current, 3);

        // Try to set limit below current count
        vm.expectRevert(MarketplaceAccessControl__MemberLimitBelowCurrent.selector);
        accessControl.setRoleMemberLimit(MODERATOR_ROLE, 2);
    }

    // ============================================================================
    // PERMISSION TESTS
    // ============================================================================

    function test_HasPermission_AdminHasAll() public {
        vm.startPrank(owner);

        assertTrue(accessControl.hasPermission(owner, "EMERGENCY_ACTION"));
        assertTrue(accessControl.hasPermission(owner, "UPDATE_FEES"));
        assertTrue(accessControl.hasPermission(owner, "VERIFY_COLLECTIONS"));
        assertTrue(accessControl.hasPermission(owner, "PAUSE_CONTRACTS"));
        assertTrue(accessControl.hasPermission(owner, "MODERATE_CONTENT"));
    }

    function test_HasPermission_SpecificRoles() public {
        vm.startPrank(owner);

        // Grant specific roles
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Test moderator");
        accessControl.grantRoleWithReason(OPERATOR_ROLE, operator1, "Test operator");
        accessControl.grantRoleWithReason(VERIFIER_ROLE, verifier1, "Test verifier");

        // Test moderator permissions
        assertTrue(accessControl.hasPermission(moderator1, "EMERGENCY_ACTION"));
        assertTrue(accessControl.hasPermission(moderator1, "MODERATE_CONTENT"));
        assertFalse(accessControl.hasPermission(moderator1, "UPDATE_FEES"));

        // Test operator permissions
        assertTrue(accessControl.hasPermission(operator1, "UPDATE_FEES"));
        assertFalse(accessControl.hasPermission(operator1, "EMERGENCY_ACTION"));

        // Test verifier permissions
        assertTrue(accessControl.hasPermission(verifier1, "VERIFY_COLLECTIONS"));
        assertFalse(accessControl.hasPermission(verifier1, "UPDATE_FEES"));
    }

    function test_HasPermission_NoRole() public {
        assertFalse(accessControl.hasPermission(user1, "EMERGENCY_ACTION"));
        assertFalse(accessControl.hasPermission(user1, "UPDATE_FEES"));
        assertFalse(accessControl.hasPermission(user1, "VERIFY_COLLECTIONS"));
    }

    // ============================================================================
    // BATCH OPERATIONS TESTS
    // ============================================================================

    function test_BatchGrantRoles_Success() public {
        vm.startPrank(owner);

        bytes32[] memory roles = new bytes32[](3);
        address[] memory accounts = new address[](3);
        string[] memory reasons = new string[](3);

        roles[0] = MODERATOR_ROLE;
        roles[1] = OPERATOR_ROLE;
        roles[2] = VERIFIER_ROLE;

        accounts[0] = moderator1;
        accounts[1] = operator1;
        accounts[2] = verifier1;

        reasons[0] = "Batch moderator";
        reasons[1] = "Batch operator";
        reasons[2] = "Batch verifier";

        vm.expectEmit(true, false, false, true);
        emit BatchRoleOperationCompleted("GRANT", 3, owner, block.timestamp);

        accessControl.batchGrantRoles(roles, accounts, reasons);

        assertTrue(accessControl.hasRole(MODERATOR_ROLE, moderator1));
        assertTrue(accessControl.hasRole(OPERATOR_ROLE, operator1));
        assertTrue(accessControl.hasRole(VERIFIER_ROLE, verifier1));
    }

    function test_BatchGrantRoles_RevertArrayLengthMismatch() public {
        vm.startPrank(owner);

        bytes32[] memory roles = new bytes32[](2);
        address[] memory accounts = new address[](3); // Different length
        string[] memory reasons = new string[](2);

        vm.expectRevert(MarketplaceAccessControl__ArrayLengthMismatch.selector);
        accessControl.batchGrantRoles(roles, accounts, reasons);
    }

    function test_BatchGrantRoles_RevertZeroAddress() public {
        vm.startPrank(owner);

        bytes32[] memory roles = new bytes32[](2);
        address[] memory accounts = new address[](2);
        string[] memory reasons = new string[](2);

        roles[0] = MODERATOR_ROLE;
        roles[1] = OPERATOR_ROLE;

        accounts[0] = moderator1;
        accounts[1] = address(0); // Invalid address

        reasons[0] = "Valid";
        reasons[1] = "Invalid";

        vm.expectRevert(MarketplaceAccessControl__ZeroAddress.selector);
        accessControl.batchGrantRoles(roles, accounts, reasons);
    }

    function test_BatchRevokeRoles_Success() public {
        vm.startPrank(owner);

        // Grant roles first
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Initial");
        accessControl.grantRoleWithReason(OPERATOR_ROLE, operator1, "Initial");

        bytes32[] memory roles = new bytes32[](2);
        address[] memory accounts = new address[](2);
        string[] memory reasons = new string[](2);

        roles[0] = MODERATOR_ROLE;
        roles[1] = OPERATOR_ROLE;

        accounts[0] = moderator1;
        accounts[1] = operator1;

        reasons[0] = "Batch revoke moderator";
        reasons[1] = "Batch revoke operator";

        vm.expectEmit(true, false, false, true);
        emit BatchRoleOperationCompleted("REVOKE", 2, owner, block.timestamp);

        accessControl.batchRevokeRoles(roles, accounts, reasons);

        assertFalse(accessControl.hasRole(MODERATOR_ROLE, moderator1));
        assertFalse(accessControl.hasRole(OPERATOR_ROLE, operator1));
    }

    // ============================================================================
    // VIEW FUNCTION TESTS
    // ============================================================================

    function test_GetActiveRoles_Success() public {
        vm.startPrank(owner);

        // Grant multiple roles to user
        accessControl.grantRoleWithReason(MODERATOR_ROLE, user1, "Test");
        accessControl.grantRoleWithReason(OPERATOR_ROLE, user1, "Test");

        bytes32[] memory activeRoles = accessControl.getActiveRoles(user1);
        assertEq(activeRoles.length, 2);

        // Check that both roles are in the array
        bool hasModerator = false;
        bool hasOperator = false;
        for (uint256 i = 0; i < activeRoles.length; i++) {
            if (activeRoles[i] == MODERATOR_ROLE) hasModerator = true;
            if (activeRoles[i] == OPERATOR_ROLE) hasOperator = true;
        }
        assertTrue(hasModerator);
        assertTrue(hasOperator);
    }

    function test_GetActiveRoles_NoRoles() public {
        bytes32[] memory activeRoles = accessControl.getActiveRoles(user1);
        assertEq(activeRoles.length, 0);
    }

    function test_GetRoleHistory_Success() public {
        vm.startPrank(owner);

        // Grant and revoke role to create history
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Initial grant");
        accessControl.revokeRoleWithReason(MODERATOR_ROLE, moderator1, "Temporary revoke");
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "Re-grant");

        MarketplaceAccessControl.RoleAssignment[] memory history =
            accessControl.getRoleHistory(MODERATOR_ROLE, moderator1);

        assertEq(history.length, 3);
        assertEq(history[0].reason, "Initial grant");
        assertEq(history[1].reason, "Temporary revoke");
        assertEq(history[2].reason, "Re-grant");

        assertTrue(history[0].isActive == false); // Revoked
        assertTrue(history[1].isActive == false); // Was revoked
        assertTrue(history[2].isActive == true); // Currently active
    }

    // ============================================================================
    // INTEGRATION TESTS
    // ============================================================================

    function test_Integration_CompleteRoleLifecycle() public {
        vm.startPrank(owner);

        // 1. Grant role
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator1, "New moderator");
        assertTrue(accessControl.hasRole(MODERATOR_ROLE, moderator1));

        // 2. Check permissions
        assertTrue(accessControl.hasPermission(moderator1, "EMERGENCY_ACTION"));
        assertTrue(accessControl.hasPermission(moderator1, "MODERATE_CONTENT"));

        // 3. Deactivate role
        accessControl.setRoleActive(MODERATOR_ROLE, false);
        assertFalse(accessControl.activeRoles(MODERATOR_ROLE));

        // 4. Try to grant role while inactive (should fail)
        vm.expectRevert(MarketplaceAccessControl__RoleNotActive.selector);
        accessControl.grantRoleWithReason(MODERATOR_ROLE, moderator2, "Should fail");

        // 5. Reactivate role
        accessControl.setRoleActive(MODERATOR_ROLE, true);
        assertTrue(accessControl.activeRoles(MODERATOR_ROLE));

        // 6. Revoke role
        accessControl.revokeRoleWithReason(MODERATOR_ROLE, moderator1, "End of term");
        assertFalse(accessControl.hasRole(MODERATOR_ROLE, moderator1));

        // 7. Check history
        MarketplaceAccessControl.RoleAssignment[] memory history =
            accessControl.getRoleHistory(MODERATOR_ROLE, moderator1);
        assertEq(history.length, 2); // Grant and revoke
    }

    // ============================================================================
    // FUZZ TESTS
    // ============================================================================

    function testFuzz_GrantRoleWithReason(address account, string calldata reason) public {
        vm.assume(account != address(0));
        vm.assume(account != owner); // Owner already has admin role
        vm.assume(bytes(reason).length > 0 && bytes(reason).length < 100);

        vm.startPrank(owner);

        accessControl.grantRoleWithReason(MODERATOR_ROLE, account, reason);
        assertTrue(accessControl.hasRole(MODERATOR_ROLE, account));

        MarketplaceAccessControl.RoleAssignment[] memory history = accessControl.getRoleHistory(MODERATOR_ROLE, account);
        assertEq(history.length, 1);
        assertEq(history[0].reason, reason);
    }

    function testFuzz_SetRoleMemberLimit(uint256 limit) public {
        vm.assume(limit > 0 && limit <= 1000);

        vm.startPrank(owner);

        accessControl.setRoleMemberLimit(MODERATOR_ROLE, limit);

        (, uint256 maxMembers) = accessControl.getRoleMemberInfo(MODERATOR_ROLE);
        assertEq(maxMembers, limit);
    }
}
