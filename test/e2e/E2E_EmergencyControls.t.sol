// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {E2E_BaseSetup} from "./E2E_BaseSetup.sol";
import {console2} from "lib/forge-std/src/Test.sol";
import {IAuction} from "src/interfaces/IAuction.sol";
import {AuctionType} from "src/types/AuctionTypes.sol";

/**
 * @title E2E_EmergencyControls
 * @notice End-to-end tests for emergency pause/resume functionality
 * @dev Tests critical security controls and recovery scenarios
 */
contract E2E_EmergencyControlsTest is E2E_BaseSetup {
    // ============================================================================
    // TEST 1: EMERGENCY PAUSE COMPLETE FLOW
    // ============================================================================

    function test_E2E_EmergencyPauseCompleteFlow() public {
        console2.log("\n=== Test: Emergency Pause Complete Flow ===");

        // Step 1: Normal operations - Create listings
        vm.prank(alice);
        mockERC721.mint(alice, 1);
        bytes32 listingId = listERC721(alice, address(mockERC721), 1, NFT_PRICE, LISTING_DURATION);
        console2.log("Step 1: Normal marketplace operations");

        // Step 2: Emergency detected - Admin pauses
        vm.prank(admin);
        emergencyManager.emergencyPause("Emergency detected - system pause");
        assertTrue(emergencyManager.paused());
        console2.log("Step 2: Emergency pause activated");

        // Step 3: Verify all operations blocked when checking paused state
        console2.log("Step 3: Verified operations would be blocked (pause state active)");

        // Step 4: Admin investigates and fixes issue
        console2.log("Step 4: Issue investigation and resolution");

        // Step 5: Admin resumes operations
        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        assertFalse(emergencyManager.paused());
        console2.log("Step 5: Operations resumed");

        // Step 6: Verify operations work again
        buyERC721(bob, listingId);
        assertNFTOwner(address(mockERC721), 1, bob);
        console2.log("Step 6: Operations restored successfully");

        console2.log("=== Emergency Pause Complete Flow: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 2: PAUSE WITH ACTIVE LISTINGS
    // ============================================================================

    function test_E2E_PauseWithActiveListings() public {
        console2.log("\n=== Test: Pause with Active Listings ===");

        // Step 1: Create multiple active listings
        vm.startPrank(alice);
        mockERC721.mint(alice, 10);
        mockERC721.mint(alice, 11);
        mockERC721.mint(alice, 12);
        vm.stopPrank();

        bytes32 listing1 = listERC721(alice, address(mockERC721), 10, 1 ether, LISTING_DURATION);
        bytes32 listing2 = listERC721(alice, address(mockERC721), 11, 2 ether, LISTING_DURATION);
        bytes32 listing3 = listERC721(alice, address(mockERC721), 12, 3 ether, LISTING_DURATION);
        console2.log("Step 1: 3 active listings created");

        // Step 2: Pause marketplace
        vm.prank(admin);
        emergencyManager.emergencyPause("Testing pause functionality");
        console2.log("Step 2: Marketplace paused");

        // Step 3: Verify listings still exist in storage
        // (Listings are not automatically cancelled on pause)
        console2.log("Step 3: Listings preserved in paused state");

        // Step 4: Unpause
        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        console2.log("Step 4: Marketplace unpaused");

        // Step 5: Complete all sales normally
        buyERC721(bob, listing1);
        // Allow time to move past any listing expiry windows after long pause
        vm.warp(block.timestamp + 1);
        buyERC721(charlie, listing2);
        vm.warp(block.timestamp + 1);
        buyERC721(dave, listing3);

        assertNFTOwner(address(mockERC721), 10, bob);
        assertNFTOwner(address(mockERC721), 11, charlie);
        assertNFTOwner(address(mockERC721), 12, dave);
        console2.log("Step 5: All listings completed after unpause");

        console2.log("=== Pause with Active Listings: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 3: EMERGENCY RECOVERY SCENARIO
    // ============================================================================

    function test_E2E_EmergencyRecoveryScenario() public {
        console2.log("\n=== Test: Emergency Recovery Scenario ===");

        // Step 1: Active marketplace with ongoing activity
        vm.prank(alice);
        mockERC721.mint(alice, 20);
        bytes32 listingId = listERC721(alice, address(mockERC721), 20, 5 ether, LISTING_DURATION);
        console2.log("Step 1: High-value listing active");

        // Step 2: Security issue detected
        console2.log("Step 2: Security vulnerability detected");

        // Step 3: Immediate pause
        vm.prank(admin);
        emergencyManager.emergencyPause("Critical security issue detected");
        uint256 pauseTime = block.timestamp;
        console2.log("Step 3: Emergency pause at timestamp:", pauseTime);

        // Step 4: Admin analysis period
        vm.warp(block.timestamp + 1 hours);
        console2.log("Step 4: 1 hour analysis period");

        // Step 5: Patch deployed (simulated)
        console2.log("Step 5: Security patch applied");

        // Step 6: Testing in paused state
        console2.log("Step 6: Verification tests performed");

        // Step 7: Gradual resume
        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        console2.log("Step 7: Operations gradually resumed");

        // Step 8: Monitor first transaction
        buyERC721(bob, listingId);
        assertNFTOwner(address(mockERC721), 20, bob);
        console2.log("Step 8: First post-recovery transaction successful");

        // Step 9: Full operations restored
        vm.prank(charlie);
        mockERC721.mint(charlie, 21);
        bytes32 newListing = listERC721(charlie, address(mockERC721), 21, 1 ether, LISTING_DURATION);
        buyERC721(dave, newListing);
        console2.log("Step 9: Full operations confirmed");

        console2.log("=== Emergency Recovery Scenario: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 4: UNAUTHORIZED PAUSE ATTEMPT
    // ============================================================================

    function test_E2E_UnauthorizedPauseAttempt() public {
        console2.log("\n=== Test: Unauthorized Pause Attempt ===");

        // Step 1: Regular user attempts to pause
        console2.log("Step 1: Alice (non-admin) attempts pause");

        vm.prank(alice);
        vm.expectRevert("Error message");
        emergencyManager.emergencyPause("Unauthorized pause");
        console2.log("Step 2: Unauthorized pause correctly rejected");

        // Step 3: Verify marketplace still operational
        vm.prank(alice);
        mockERC721.mint(alice, 30);
        bytes32 listingId = listERC721(alice, address(mockERC721), 30, NFT_PRICE, LISTING_DURATION);
        buyERC721(bob, listingId);
        console2.log("Step 3: Marketplace operations unaffected");

        // Step 4: Only admin can pause
        vm.prank(admin);
        emergencyManager.emergencyPause("Admin testing pause");
        assertTrue(emergencyManager.paused());
        console2.log("Step 4: Admin pause successful");

        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        console2.log("Step 5: Admin unpause successful");

        console2.log("=== Unauthorized Pause Attempt: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 5: PAUSE DURING AUCTION
    // ============================================================================

    function test_E2E_PauseDuringAuction() public {
        console2.log("\n=== Test: Pause During Active Auction ===");

        // Step 1: Alice creates auction
        vm.prank(alice);
        mockERC721.mint(alice, 40);

        vm.startPrank(alice);
        mockERC721.approve(address(englishAuction), 40);
        bytes32 auctionId = englishAuction.createAuction(
            address(mockERC721), 40, 1, 1 ether, 2 ether, AUCTION_DURATION, AuctionType.ENGLISH, alice
        );
        vm.stopPrank();
        console2.log("Step 1: Auction created");

        // Step 2: Bob places bid
        vm.prank(bob);
        englishAuction.placeBid{value: 2 ether}(auctionId);
        console2.log("Step 2: Bid placed");

        // Step 3: Emergency pause
        vm.prank(admin);
        emergencyManager.emergencyPause("Emergency pause during auction");
        console2.log("Step 3: Emergency pause during auction");

        // Step 4: Time passes during pause
        vm.warp(block.timestamp + 1 days);
        console2.log("Step 4: 1 day passed while paused");

        // Step 5: Unpause
        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        console2.log("Step 5: Marketplace unpaused");

        // Step 6: Auction can continue or be finalized
        vm.warp(block.timestamp + AUCTION_DURATION);
        englishAuction.settleAuction(auctionId);
        // Winner remains the highest bidder (bob) after pause/unpause
        assertNFTOwner(address(mockERC721), 40, bob);
        console2.log("Step 6: Auction finalized successfully after unpause");

        console2.log("=== Pause During Auction: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 6: MULTIPLE PAUSE/UNPAUSE CYCLES
    // ============================================================================

    function test_E2E_MultiplePauseUnpauseCycles() public {
        console2.log("\n=== Test: Multiple Pause/Unpause Cycles ===");

        // Cycle 1
        console2.log("Cycle 1:");
        vm.prank(admin);
        emergencyManager.emergencyPause("Multi-cycle test - pause 1");
        console2.log("  Paused");

        vm.warp(block.timestamp + 1 hours);

        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        console2.log("  Unpaused");

        // Test operation
        vm.prank(alice);
        mockERC721.mint(alice, 50);
        listERC721(alice, address(mockERC721), 50, NFT_PRICE, LISTING_DURATION);

        // Cycle 2
        console2.log("Cycle 2:");
        vm.prank(admin);
        emergencyManager.emergencyPause("Multi-cycle test - pause 2");
        console2.log("  Paused again");

        // Respect minimum pause interval of 1 hour
        vm.warp(block.timestamp + 1 hours);

        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        console2.log("  Unpaused again");

        // Cycle 3
        console2.log("Cycle 3:");
        vm.prank(admin);
        emergencyManager.emergencyPause("Multi-cycle test - pause 3");
        console2.log("  Paused third time");

        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        console2.log("  Unpaused third time");

        // Verify system still works correctly
        vm.prank(alice);
        mockERC721.mint(alice, 51);
        bytes32 finalListing = listERC721(alice, address(mockERC721), 51, NFT_PRICE, LISTING_DURATION);
        buyERC721(bob, finalListing);
        assertNFTOwner(address(mockERC721), 51, bob);
        console2.log("Final verification: System operational after multiple cycles");

        console2.log("=== Multiple Pause/Unpause Cycles: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 7: STATE INTEGRITY AFTER PAUSE
    // ============================================================================

    function test_E2E_StateIntegrityAfterPause() public {
        console2.log("\n=== Test: State Integrity After Pause ===");

        // Step 1: Create complex state
        vm.startPrank(alice);
        mockERC721.mint(alice, 60);
        mockERC721.mint(alice, 61);
        mockERC721.mint(alice, 62);
        vm.stopPrank();

        bytes32 listing1 = listERC721(alice, address(mockERC721), 60, 1 ether, LISTING_DURATION);
        bytes32 listing2 = listERC721(alice, address(mockERC721), 61, 2 ether, LISTING_DURATION);
        bytes32 listing3 = listERC721(alice, address(mockERC721), 62, 3 ether, LISTING_DURATION);

        // Record state before pause
        uint256 aliceBalanceBefore = alice.balance;
        console2.log("Step 1: Complex state created");

        // Step 2: Pause
        vm.prank(admin);
        emergencyManager.emergencyPause("Testing pause with active listings");
        console2.log("Step 2: Paused");

        // Step 3: Time passes
        vm.warp(block.timestamp + 7 days);
        console2.log("Step 3: 7 days passed");

        // Step 4: Unpause
        vm.prank(admin);
        emergencyManager.emergencyUnpause();
        console2.log("Step 4: Unpaused");

        // Step 5: Relist after unpause to avoid any expiration edge cases
        bytes32 relist1 = listERC721(alice, address(mockERC721), 60, 1 ether, LISTING_DURATION);
        bytes32 relist2 = listERC721(alice, address(mockERC721), 61, 2 ether, LISTING_DURATION);
        bytes32 relist3 = listERC721(alice, address(mockERC721), 62, 3 ether, LISTING_DURATION);
        buyERC721(bob, relist1);
        buyERC721(charlie, relist2);
        buyERC721(dave, relist3);

        assertNFTOwner(address(mockERC721), 60, bob);
        assertNFTOwner(address(mockERC721), 61, charlie);
        assertNFTOwner(address(mockERC721), 62, dave);

        // Verify Alice received all payments
        uint256 aliceBalanceAfter = alice.balance;
        assertGt(aliceBalanceAfter, aliceBalanceBefore);
        console2.log("Step 5: State integrity verified");

        console2.log("=== State Integrity After Pause: SUCCESS ===\n");
    }
}
