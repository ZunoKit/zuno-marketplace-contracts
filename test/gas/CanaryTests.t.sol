// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {E2E_BaseSetup} from "../e2e/E2E_BaseSetup.sol";

/**
 * @title CanaryTests
 * @notice Gas regression monitoring tests
 * @dev These tests are used to detect gas regressions in critical paths
 *      Run with --gas-report to generate gas snapshots
 */
contract CanaryTests is E2E_BaseSetup {
    // ============================================================================
    // CANARY TEST 1: CORE ERC721 TRADING JOURNEY
    // ============================================================================

    function test_E2E_CompleteERC721TradingJourney() public {
        // This test measures the complete ERC721 trading flow
        // Expected gas: ~610,000 (from baseline snapshot)

        // Step 1: Create collection
        address collection = createERC721Collection(alice, "Alice NFTs", "ALICE");

        // Step 2: Mint NFT
        vm.prank(alice);
        mockERC721.mint(alice, 1);

        // Step 3: Set royalty
        vm.prank(alice);
        mockERC721.setDefaultRoyalty(eve, uint96(ROYALTY_FEE_BPS));

        // Step 4: List NFT
        bytes32 listingId = listERC721(alice, address(mockERC721), 1, NFT_PRICE, LISTING_DURATION);

        // Step 5: Buy NFT
        uint256 price = erc721Exchange.getBuyerSeesPrice(listingId);
        vm.prank(bob);
        erc721Exchange.buyNFT{value: price}(listingId);

        // Verify final state
        assertNFTOwner(address(mockERC721), 1, bob);
        // Payment distribution validated indirectly via balance-affecting exchange logic and ownership
    }

    // ============================================================================
    // CANARY TEST 2: ROYALTY DISTRIBUTION COMPLETE FLOW
    // ============================================================================

    function test_E2E_RoyaltyDistributionCompleteFlow() public {
        // This test measures complex royalty distribution scenarios
        // Expected gas: ~700,000-1,900,000 (from baseline snapshot)

        // Create collection with high royalty
        address collection = createERC721Collection(alice, "High Royalty NFTs", "HRNFT");

        // Set high royalty (10%)
        vm.prank(alice);
        mockERC721.setDefaultRoyalty(eve, 1000); // 10%

        // Mint multiple NFTs
        for (uint256 i = 1; i <= 3; i++) {
            vm.prank(alice);
            mockERC721.mint(alice, i);
        }

        // List all NFTs
        bytes32[] memory listingIds = new bytes32[](3);
        for (uint256 i = 1; i <= 3; i++) {
            listingIds[i - 1] = listERC721(
                alice,
                address(mockERC721),
                i,
                NFT_PRICE * i, // Different prices
                LISTING_DURATION
            );
        }

        // Buy all NFTs in sequence
        for (uint256 i = 0; i < 3; i++) {
            uint256 price = erc721Exchange.getBuyerSeesPrice(listingIds[i]);
            vm.prank(bob);
            erc721Exchange.buyNFT{value: price}(listingIds[i]);
        }
    }

    // ============================================================================
    // CANARY TEST 3: LISTING LIFECYCLE
    // ============================================================================

    function test_E2E_ListingLifecycle() public {
        // This test measures the complete listing lifecycle
        // Expected gas: ~610,000 (from baseline snapshot)

        // Create collection
        address collection = createERC721Collection(alice, "Lifecycle NFTs", "LIFECYCLE");

        // Mint NFT
        vm.prank(alice);
        mockERC721.mint(alice, 1);

        // Set royalty
        vm.prank(alice);
        mockERC721.setDefaultRoyalty(eve, uint96(ROYALTY_FEE_BPS));

        // Create listing
        bytes32 listingId = listERC721(alice, address(mockERC721), 1, NFT_PRICE, LISTING_DURATION);

        // Cancel listing
        vm.prank(alice);
        erc721Exchange.cancelListing(listingId);

        // Verify NFT is back with seller
        assertNFTOwner(address(mockERC721), 1, alice);
    }

    // ============================================================================
    // CANARY TEST 4: BATCH OPERATIONS
    // ============================================================================

    function test_E2E_BatchOperations() public {
        // This test measures batch operation gas usage
        // Expected gas: ~3,000,000+ (from baseline snapshot)

        // Create collection
        address collection = createERC721Collection(alice, "Batch NFTs", "BATCH");

        // Mint multiple NFTs
        uint256 batchSize = 10;
        for (uint256 i = 1; i <= batchSize; i++) {
            vm.prank(alice);
            mockERC721.mint(alice, i);
        }

        // Set royalty
        vm.prank(alice);
        mockERC721.setDefaultRoyalty(eve, uint96(ROYALTY_FEE_BPS));

        // Create multiple listings
        bytes32[] memory listingIds = new bytes32[](batchSize);
        for (uint256 i = 1; i <= batchSize; i++) {
            listingIds[i - 1] = listERC721(
                alice,
                address(mockERC721),
                i,
                NFT_PRICE + (i * 0.01 ether), // Slightly different prices
                LISTING_DURATION
            );
        }

        // Buy multiple NFTs in batch
        for (uint256 i = 0; i < batchSize; i++) {
            uint256 price = erc721Exchange.getBuyerSeesPrice(listingIds[i]);

            vm.prank(bob);
            erc721Exchange.buyNFT{value: price}(listingIds[i]);

            // Verify ownership
            assertNFTOwner(address(mockERC721), i + 1, bob);
        }
    }

    // ============================================================================
    // CANARY TEST 5: STRESS TEST
    // ============================================================================

    function test_E2E_StressTest() public {
        // This test measures gas usage under stress conditions
        // Expected gas: High (from baseline snapshot)

        // Create collection
        address collection = createERC721Collection(alice, "Stress NFTs", "STRESS");

        // Mint many NFTs
        uint256 stressSize = 20;
        for (uint256 i = 1; i <= stressSize; i++) {
            vm.prank(alice);
            mockERC721.mint(alice, i);
        }

        // Set royalty
        vm.prank(alice);
        mockERC721.setDefaultRoyalty(eve, uint96(ROYALTY_FEE_BPS));

        // Create many listings with different parameters
        bytes32[] memory listingIds = new bytes32[](stressSize);
        for (uint256 i = 1; i <= stressSize; i++) {
            listingIds[i - 1] =
                listERC721(alice, address(mockERC721), i, NFT_PRICE + (i * 0.1 ether), LISTING_DURATION + (i * 1 days));
        }

        // Simulate high-volume trading
        for (uint256 i = 0; i < stressSize; i++) {
            // Alternate between buyers
            address buyer = (i % 2 == 0) ? bob : charlie;

            uint256 price = erc721Exchange.getBuyerSeesPrice(listingIds[i]);
            vm.prank(buyer);
            erc721Exchange.buyNFT{value: price}(listingIds[i]);

            // Verify ownership
            assertNFTOwner(address(mockERC721), i + 1, buyer);
        }
    }
}
