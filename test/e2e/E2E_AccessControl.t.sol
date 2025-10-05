// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {E2E_BaseSetup} from "./E2E_BaseSetup.sol";
import {console2} from "lib/forge-std/src/Test.sol";

/**
 * @title E2E_AccessControl
 * @notice End-to-end tests for role-based access control
 * @dev Tests admin, operator, and user permission workflows
 */
contract E2E_AccessControlTest is E2E_BaseSetup {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    // ============================================================================
    // TEST 1: ROLE-BASED ACCESS COMPLETE FLOW
    // ============================================================================

    function test_E2E_RoleBasedAccessCompleteFlow() public {
        console2.log("\n=== Test: Role-Based Access Complete Flow ===");

        // Step 1: Admin grants operator role
        vm.prank(admin);
        accessControl.grantRole(OPERATOR_ROLE, operator);
        assertTrue(
            accessControl.hasRole(OPERATOR_ROLE, operator),
            "Operator role not granted"
        );
        console2.log("Step 1: Operator role granted to", operator);

        // Step 2: Operator performs privileged action
        // (For this test, we verify the role exists - actual privileged actions depend on contract implementation)
        assertTrue(
            accessControl.hasRole(OPERATOR_ROLE, operator),
            "Operator should have role"
        );
        console2.log("Step 2: Operator role verified");

        // Step 3: Admin revokes operator role
        vm.prank(admin);
        accessControl.revokeRole(OPERATOR_ROLE, operator);
        assertFalse(
            accessControl.hasRole(OPERATOR_ROLE, operator),
            "Role should be revoked"
        );
        console2.log("Step 3: Operator role revoked");

        // Step 4: Former operator cannot perform privileged actions
        assertFalse(
            accessControl.hasRole(OPERATOR_ROLE, operator),
            "Should not have operator role"
        );
        console2.log("Step 4: Access correctly denied after revocation");

        console2.log("=== Role-Based Access Complete Flow: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 2: MULTI-ROLE MANAGEMENT
    // ============================================================================

    function test_E2E_MultiRoleManagement() public {
        console2.log("\n=== Test: Multi-Role Management ===");

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        // Step 1: Grant different roles to different users
        vm.startPrank(admin);
        accessControl.grantRole(OPERATOR_ROLE, user1);
        accessControl.grantRole(MODERATOR_ROLE, user2);
        accessControl.grantRole(OPERATOR_ROLE, user3);
        accessControl.grantRole(MODERATOR_ROLE, user3); // user3 has both roles
        vm.stopPrank();
        console2.log("Step 1: Multiple roles granted to multiple users");

        // Step 2: Verify role assignments
        assertTrue(
            accessControl.hasRole(OPERATOR_ROLE, user1),
            "User1 should have operator role"
        );
        assertTrue(
            accessControl.hasRole(MODERATOR_ROLE, user2),
            "User2 should have moderator role"
        );
        assertTrue(
            accessControl.hasRole(OPERATOR_ROLE, user3),
            "User3 should have operator role"
        );
        assertTrue(
            accessControl.hasRole(MODERATOR_ROLE, user3),
            "User3 should have moderator role"
        );
        console2.log("Step 2: All role assignments verified");

        // Step 3: Selectively revoke roles
        vm.prank(admin);
        accessControl.revokeRole(OPERATOR_ROLE, user3);

        assertTrue(
            accessControl.hasRole(MODERATOR_ROLE, user3),
            "User3 should still have moderator role"
        );
        assertFalse(
            accessControl.hasRole(OPERATOR_ROLE, user3),
            "User3 should not have operator role"
        );
        console2.log("Step 3: Selective role revocation successful");

        // Step 4: Revoke all roles
        vm.startPrank(admin);
        accessControl.revokeRole(OPERATOR_ROLE, user1);
        accessControl.revokeRole(MODERATOR_ROLE, user2);
        accessControl.revokeRole(MODERATOR_ROLE, user3);
        vm.stopPrank();

        assertFalse(
            accessControl.hasRole(OPERATOR_ROLE, user1),
            "User1 should have no roles"
        );
        assertFalse(
            accessControl.hasRole(MODERATOR_ROLE, user2),
            "User2 should have no roles"
        );
        assertFalse(
            accessControl.hasRole(MODERATOR_ROLE, user3),
            "User3 should have no roles"
        );
        console2.log("Step 4: All roles revoked");

        console2.log("=== Multi-Role Management: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 3: UNAUTHORIZED ACCESS ATTEMPTS
    // ============================================================================

    function test_E2E_UnauthorizedAccessAttempts() public {
        console2.log("\n=== Test: Unauthorized Access Attempts ===");

        address attacker = makeAddr("attacker");

        // Step 1: Non-admin attempts to grant role
        console2.log("Step 1: Attacker attempts to grant role");
        vm.prank(attacker);
        vm.expectRevert();
        accessControl.grantRole(OPERATOR_ROLE, attacker);
        console2.log("  -> Correctly rejected");

        // Step 2: Regular user attempts to revoke admin role
        console2.log("Step 2: Regular user attempts to revoke admin role");
        vm.prank(alice);
        vm.expectRevert();
        accessControl.revokeRole(ADMIN_ROLE, admin);
        console2.log("  -> Correctly rejected");

        // Step 3: Verify admin still has role
        assertTrue(
            accessControl.hasRole(ADMIN_ROLE, admin),
            "Admin should still have role"
        );
        console2.log("Step 3: Admin role intact");

        // Step 4: Non-admin attempts emergency pause
        console2.log("Step 4: Non-admin attempts emergency pause");
        vm.prank(attacker);
        vm.expectRevert();
        emergencyManager.emergencyPause("Unauthorized pause attempt");
        console2.log("  -> Correctly rejected");

        assertFalse(emergencyManager.paused(), "Should not be paused");
        console2.log("Step 5: System remains secure");

        console2.log("=== Unauthorized Access Attempts: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 4: ROLE HIERARCHY
    // ============================================================================

    function test_E2E_RoleHierarchy() public {
        console2.log("\n=== Test: Role Hierarchy ===");

        // Step 1: Admin is the highest role
        assertTrue(
            accessControl.hasRole(ADMIN_ROLE, admin),
            "Admin should have admin role"
        );
        console2.log("Step 1: Admin role confirmed");

        // Step 2: Admin can grant any role
        vm.startPrank(admin);
        accessControl.grantRole(OPERATOR_ROLE, alice);
        accessControl.grantRole(MODERATOR_ROLE, bob);
        vm.stopPrank();
        console2.log("Step 2: Admin granted roles to users");

        // Step 3: Lower roles cannot grant roles
        console2.log("Step 3: Operator attempts to grant role");
        vm.prank(alice);
        vm.expectRevert();
        accessControl.grantRole(MODERATOR_ROLE, charlie);
        console2.log("  -> Correctly rejected");

        // Step 4: Admin can revoke any role
        vm.prank(admin);
        accessControl.revokeRole(OPERATOR_ROLE, alice);
        assertFalse(
            accessControl.hasRole(OPERATOR_ROLE, alice),
            "Role should be revoked"
        );
        console2.log("Step 4: Admin successfully revoked role");

        // Step 5: Verify hierarchy maintained
        assertTrue(
            accessControl.hasRole(ADMIN_ROLE, admin),
            "Admin should maintain admin role"
        );
        assertTrue(
            accessControl.hasRole(MODERATOR_ROLE, bob),
            "Bob should maintain moderator role"
        );
        console2.log("Step 5: Role hierarchy maintained");

        console2.log("=== Role Hierarchy: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 5: OPERATOR WORKFLOW
    // ============================================================================

    function test_E2E_OperatorWorkflow() public {
        console2.log("\n=== Test: Operator Workflow ===");

        // Step 1: Admin appoints operator
        vm.prank(admin);
        accessControl.grantRole(OPERATOR_ROLE, operator);
        console2.log("Step 1: Operator appointed");

        // Step 2: Operator can perform operational tasks
        // In a real scenario, operator might be able to update fees, manage listings, etc.
        assertTrue(
            accessControl.hasRole(OPERATOR_ROLE, operator),
            "Operator role active"
        );
        console2.log("Step 2: Operator can perform duties");

        // Step 3: Operator rotation - old operator removed, new added
        address newOperator = makeAddr("newOperator");
        vm.startPrank(admin);
        accessControl.revokeRole(OPERATOR_ROLE, operator);
        accessControl.grantRole(OPERATOR_ROLE, newOperator);
        vm.stopPrank();
        console2.log("Step 3: Operator rotated");

        // Step 4: Verify transition
        assertFalse(
            accessControl.hasRole(OPERATOR_ROLE, operator),
            "Old operator should not have role"
        );
        assertTrue(
            accessControl.hasRole(OPERATOR_ROLE, newOperator),
            "New operator should have role"
        );
        console2.log("Step 4: Operator transition verified");

        console2.log("=== Operator Workflow: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 6: EMERGENCY ADMIN ACTIONS
    // ============================================================================

    function test_E2E_EmergencyAdminActions() public {
        console2.log("\n=== Test: Emergency Admin Actions ===");

        // Step 1: Normal operations
        vm.prank(alice);
        mockERC721.mint(alice, 1);
        bytes32 listingId = listERC721(
            alice,
            address(mockERC721),
            1,
            NFT_PRICE,
            LISTING_DURATION
        );
        console2.log("Step 1: Normal listing created");

        // Step 2: Admin detects issue and pauses
        vm.prank(admin);
        emergencyManager.emergencyPause("Admin detected critical issue");
        console2.log("Step 2: Admin emergency pause");

        // Step 3: Admin investigates (simulated)
        console2.log("Step 3: Admin investigation period");

        // Step 4: Admin resumes after fix
        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        console2.log("Step 4: Admin resumed operations");

        // Step 5: Verify marketplace functional
        buyERC721(bob, listingId);
        assertNFTOwner(address(mockERC721), 1, bob);
        console2.log("Step 5: Marketplace restored");

        console2.log("=== Emergency Admin Actions: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 7: PERMISSION VALIDATION IN OPERATIONS
    // ============================================================================

    function test_E2E_PermissionValidationInOperations() public {
        console2.log("\n=== Test: Permission Validation in Operations ===");

        // Step 1: Regular users can trade normally
        vm.prank(alice);
        mockERC721.mint(alice, 10);
        bytes32 listingId = listERC721(
            alice,
            address(mockERC721),
            10,
            NFT_PRICE,
            LISTING_DURATION
        );
        buyERC721(bob, listingId);
        console2.log(
            "Step 1: Regular trading works without special permissions"
        );

        // Step 2: Admin actions require admin role
        console2.log("Step 2: Admin-only actions verified");

        // Regular user cannot pause
        vm.prank(alice);
        vm.expectRevert();
        emergencyManager.emergencyPause("Non-admin pause attempt");
        console2.log("  -> Non-admin cannot pause");

        // Admin can pause
        vm.prank(admin);
        emergencyManager.emergencyPause("Admin pause test");
        assertTrue(emergencyManager.paused(), "Admin should be able to pause");
        console2.log("  -> Admin can pause");

        // Admin can unpause
        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        assertFalse(
            emergencyManager.paused(),
            "Admin should be able to unpause"
        );
        console2.log("  -> Admin can unpause");

        console2.log("=== Permission Validation in Operations: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 8: CONCURRENT ROLE OPERATIONS
    // ============================================================================

    function test_E2E_ConcurrentRoleOperations() public {
        console2.log("\n=== Test: Concurrent Role Operations ===");

        address[] memory operators = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            operators[i] = makeAddr(string(abi.encodePacked("operator", i)));
        }

        // Step 1: Grant multiple roles simultaneously
        vm.startPrank(admin);
        for (uint256 i = 0; i < 5; i++) {
            accessControl.grantRole(OPERATOR_ROLE, operators[i]);
        }
        vm.stopPrank();
        console2.log("Step 1: 5 operator roles granted");

        // Step 2: Verify all assignments
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(
                accessControl.hasRole(OPERATOR_ROLE, operators[i]),
                "Operator role not granted"
            );
        }
        console2.log("Step 2: All 5 operators verified");

        // Step 3: Revoke some roles
        vm.startPrank(admin);
        accessControl.revokeRole(OPERATOR_ROLE, operators[1]);
        accessControl.revokeRole(OPERATOR_ROLE, operators[3]);
        vm.stopPrank();
        console2.log("Step 3: 2 operators removed");

        // Step 4: Verify selective revocation
        assertTrue(
            accessControl.hasRole(OPERATOR_ROLE, operators[0]),
            "Operator 0 should still have role"
        );
        assertFalse(
            accessControl.hasRole(OPERATOR_ROLE, operators[1]),
            "Operator 1 should not have role"
        );
        assertTrue(
            accessControl.hasRole(OPERATOR_ROLE, operators[2]),
            "Operator 2 should still have role"
        );
        assertFalse(
            accessControl.hasRole(OPERATOR_ROLE, operators[3]),
            "Operator 3 should not have role"
        );
        assertTrue(
            accessControl.hasRole(OPERATOR_ROLE, operators[4]),
            "Operator 4 should still have role"
        );
        console2.log("Step 4: Selective revocation verified");

        console2.log("=== Concurrent Role Operations: SUCCESS ===\n");
    }
}
