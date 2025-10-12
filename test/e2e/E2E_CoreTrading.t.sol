// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {E2E_BaseSetup} from "./E2E_BaseSetup.sol";
import {console2} from "forge-std/Test.sol";

/**
 * @title E2E_CoreTrading
 * @notice End-to-end tests for core trading functionality
 * @dev Tests complete user journeys from collection creation to trading
 */
contract E2E_CoreTradingTest is E2E_BaseSetup {
    // ============================================================================
    // TEST 1: COMPLETE ERC721 TRADING JOURNEY
    // ============================================================================

    function test_E2E_CompleteERC721TradingJourney() public {
        console2.log("\n=== Test: Complete ERC721 Trading Journey ===");

        // Step 1: Alice creates a collection
        address collection = createERC721Collection(alice, "Alice NFTs", "ALICE");
        assertFalse(collection == address(0), "Collection creation failed");

        // Step 2: Alice mints an NFT
        vm.prank(alice);
        mockERC721.mint(alice, 1);
        assertNFTOwner(address(mockERC721), 1, alice);
        console2.log("Step 1-2: Collection created and NFT minted");

        // Ensure royalty goes to a distinct receiver (eve) so seller net excludes royalty
        vm.prank(alice);
        mockERC721.setDefaultRoyalty(eve, uint96(ROYALTY_FEE_BPS));

        // Step 3: Alice lists the NFT
        bytes32 listingId = listERC721(alice, address(mockERC721), 1, NFT_PRICE, LISTING_DURATION);
        console2.log("Step 3: NFT listed");

        // Step 4: Bob buys the NFT
        BalanceSnapshot memory balancesBefore = snapshotBalances(bob, alice, marketplaceWallet, eve);

        buyERC721(bob, listingId);

        BalanceSnapshot memory balancesAfter = snapshotBalances(bob, alice, marketplaceWallet, eve);
        console2.log("Step 4: NFT purchased");

        // Step 5: Verify ownership transfer
        assertNFTOwner(address(mockERC721), 1, bob);
        console2.log("Step 5: Ownership verified");

        // Step 6: Verify payment distribution
        uint256 takerFee = (NFT_PRICE * TAKER_FEE_BPS) / 10000;
        uint256 royaltyFee = (NFT_PRICE * 500) / 10000; // 5% royalty
        uint256 totalPaid = NFT_PRICE + takerFee + royaltyFee;
        uint256 sellerReceives = NFT_PRICE - royaltyFee; // Seller receives listing price minus royalty

        assertBalanceChanges(balancesBefore, balancesAfter, totalPaid, sellerReceives, takerFee, royaltyFee);
        console2.log("Step 6: Payment distribution verified");

        console2.log("=== Complete ERC721 Trading Journey: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 2: COMPLETE ERC1155 TRADING JOURNEY
    // ============================================================================

    function test_E2E_CompleteERC1155TradingJourney() public {
        console2.log("\n=== Test: Complete ERC1155 Trading Journey ===");

        // Step 1: Alice mints ERC1155 tokens
        vm.prank(alice);
        mockERC1155.mint(alice, 1, 10);
        assertERC1155Balance(address(mockERC1155), alice, 1, 10);
        console2.log("Step 1: 10 ERC1155 tokens minted");

        // Ensure no royalty is applied for this ERC1155 journey
        vm.prank(alice);
        mockERC1155.setDefaultRoyalty(alice, 0);

        // Step 2: Alice lists 5 units for sale
        bytes32 listingId = listERC1155(alice, address(mockERC1155), 1, 5, NFT_PRICE, LISTING_DURATION);
        console2.log("Step 2: 5 units listed");

        // Step 3: Bob buys 3 units
        BalanceSnapshot memory balancesBefore = snapshotBalances(bob, alice, marketplaceWallet, address(0));

        buyERC1155(bob, listingId, 3);

        BalanceSnapshot memory balancesAfter = snapshotBalances(bob, alice, marketplaceWallet, address(0));
        console2.log("Step 3: 3 units purchased");

        // Step 4: Verify balance changes
        assertERC1155Balance(address(mockERC1155), alice, 1, 7); // 10 - 3 = 7
        assertERC1155Balance(address(mockERC1155), bob, 1, 3);
        console2.log("Step 4: Balances verified");

        // Step 5: Verify payment for 3 units (price is proportional to amount)
        uint256 totalPrice = (NFT_PRICE * 3) / 5;
        uint256 takerFee = (totalPrice * TAKER_FEE_BPS) / 10000;
        uint256 royaltyFee = 0; // no royalty on partial purchase
        uint256 totalPaid = totalPrice + takerFee;
        uint256 sellerReceives = totalPrice;

        assertBalanceChanges(balancesBefore, balancesAfter, totalPaid, sellerReceives, takerFee, royaltyFee);
        console2.log("Step 5: Payment distribution verified");

        // Step 6: Charlie buys remaining 2 units
        buyERC1155(charlie, listingId, 2);
        assertERC1155Balance(address(mockERC1155), alice, 1, 5); // 7 - 2 = 5
        assertERC1155Balance(address(mockERC1155), charlie, 1, 2);
        console2.log("Step 6: Remaining units purchased");

        console2.log("=== Complete ERC1155 Trading Journey: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 3: LISTING LIFECYCLE
    // ============================================================================

    function test_E2E_ListingLifecycle() public {
        console2.log("\n=== Test: Listing Lifecycle ===");

        // Setup: Alice has an NFT
        vm.prank(alice);
        mockERC721.mint(alice, 2);

        // Step 1: Create listing
        bytes32 listingId = listERC721(alice, address(mockERC721), 2, NFT_PRICE, LISTING_DURATION);
        console2.log("Step 1: Listing created");

        // Step 2: Cancel original listing
        vm.prank(alice);
        erc721Exchange.cancelListing(listingId);
        console2.log("Step 2: Original listing cancelled");

        // Step 3: Relist at higher price
        bytes32 higherPriceListingId = listERC721(alice, address(mockERC721), 2, NFT_PRICE * 2, LISTING_DURATION);
        console2.log("Step 3: Relisted at higher price:", NFT_PRICE * 2);

        // Step 4: Cancel again
        vm.prank(alice);
        erc721Exchange.cancelListing(higherPriceListingId);
        console2.log("Step 4: Higher price listing cancelled");

        // Step 5: Relist at lower price
        bytes32 newListingId = listERC721(alice, address(mockERC721), 2, NFT_PRICE / 2, LISTING_DURATION);
        console2.log("Step 5: NFT relisted at lower price:", NFT_PRICE / 2);

        // Step 6: Bob buys
        buyERC721(bob, newListingId);
        assertNFTOwner(address(mockERC721), 2, bob);
        console2.log("Step 6: NFT sold at new price");

        console2.log("=== Listing Lifecycle: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 4: MULTIPLE CONCURRENT LISTINGS
    // ============================================================================

    function test_E2E_MultipleConcurrentListings() public {
        console2.log("\n=== Test: Multiple Concurrent Listings ===");

        // Setup: Multiple users create listings
        vm.startPrank(alice);
        mockERC721.mint(alice, 10);
        mockERC721.mint(alice, 11);
        vm.stopPrank();

        vm.startPrank(charlie);
        mockERC721.mint(charlie, 12);
        mockERC721.mint(charlie, 13);
        vm.stopPrank();

        // Step 1: Alice lists 2 NFTs
        bytes32 listing1 = listERC721(alice, address(mockERC721), 10, 1 ether, LISTING_DURATION);
        bytes32 listing2 = listERC721(alice, address(mockERC721), 11, 2 ether, LISTING_DURATION);
        console2.log("Step 1: Alice listed 2 NFTs");

        // Step 2: Charlie lists 2 NFTs
        bytes32 listing3 = listERC721(charlie, address(mockERC721), 12, 1.5 ether, LISTING_DURATION);
        bytes32 listing4 = listERC721(charlie, address(mockERC721), 13, 0.5 ether, LISTING_DURATION);
        console2.log("Step 2: Charlie listed 2 NFTs");

        // Step 3: Bob buys cheapest listing
        buyERC721(bob, listing4);
        assertNFTOwner(address(mockERC721), 13, bob);
        console2.log("Step 3: Bob bought cheapest NFT");

        // Step 4: Dave buys from Alice
        buyERC721(dave, listing1);
        assertNFTOwner(address(mockERC721), 10, dave);
        console2.log("Step 4: Dave bought from Alice");

        // Step 5: Eve buys remaining listings
        buyERC721(eve, listing2);
        buyERC721(eve, listing3);
        assertNFTOwner(address(mockERC721), 11, eve);
        assertNFTOwner(address(mockERC721), 12, eve);
        console2.log("Step 5: Eve bought 2 NFTs");

        console2.log("=== Multiple Concurrent Listings: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 5: FAILED TRANSACTION SCENARIOS
    // ============================================================================

    function test_E2E_FailedTransactionScenarios() public {
        console2.log("\n=== Test: Failed Transaction Scenarios ===");

        // Setup
        vm.prank(alice);
        mockERC721.mint(alice, 20);
        bytes32 listingId = listERC721(alice, address(mockERC721), 20, NFT_PRICE, LISTING_DURATION);

        // Scenario 1: Insufficient funds
        console2.log("Scenario 1: Insufficient funds");
        uint256 totalPrice = erc721Exchange.getBuyerSeesPrice(listingId);
        vm.deal(bob, totalPrice - 1 ether); // Not enough ETH

        vm.prank(bob);
        vm.expectRevert();
        erc721Exchange.buyNFT{value: totalPrice - 1 ether}(listingId);
        console2.log("  -> Transaction correctly reverted");

        // Scenario 1b: Retry with correct amount
        vm.deal(bob, totalPrice);
        vm.prank(bob);
        erc721Exchange.buyNFT{value: totalPrice}(listingId);
        console2.log("  -> Retry successful");

        // Scenario 2: Try to buy already sold NFT
        console2.log("Scenario 2: Already sold NFT");
        vm.prank(charlie);
        vm.expectRevert();
        erc721Exchange.buyNFT{value: totalPrice}(listingId);
        console2.log("  -> Transaction correctly reverted");

        // Scenario 3: Expired listing
        console2.log("Scenario 3: Expired listing");
        vm.prank(alice);
        mockERC721.mint(alice, 21);
        bytes32 expiredListingId = listERC721(alice, address(mockERC721), 21, NFT_PRICE, 1 days);

        // Fast forward past expiration
        vm.warp(block.timestamp + 2 days);

        vm.prank(dave);
        vm.expectRevert();
        erc721Exchange.buyNFT{value: totalPrice}(expiredListingId);
        console2.log("  -> Expired listing correctly rejected");

        // Scenario 3b: Relist after expiration
        vm.warp(block.timestamp + 1 days); // Move time forward again
        bytes32 newListingId = listERC721(alice, address(mockERC721), 21, NFT_PRICE, LISTING_DURATION);
        buyERC721(dave, newListingId);
        console2.log("  -> Relisting successful");

        console2.log("=== Failed Transaction Scenarios: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 6: BATCH LISTING AND BUYING
    // ============================================================================

    function test_E2E_BatchListingAndBuying() public {
        console2.log("\n=== Test: Batch Listing and Buying ===");

        // Setup: Mint multiple NFTs
        uint256[] memory tokenIds = new uint256[](5);
        uint256[] memory prices = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = 100 + i;
            prices[i] = NFT_PRICE;

            vm.prank(alice);
            mockERC721.mint(alice, tokenIds[i]);
        }

        // Step 1: Batch approve
        setApprovalForAllERC721(address(mockERC721), alice, address(erc721Exchange));
        console2.log("Step 1: Batch approved");

        // Step 2: Create multiple listings
        bytes32[] memory listingIds = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(alice);
            erc721Exchange.listNFT(address(mockERC721), tokenIds[i], prices[i], LISTING_DURATION);
            listingIds[i] = erc721Exchange.getGeneratedListingId(address(mockERC721), tokenIds[i], alice);
        }
        console2.log("Step 2: Created 5 listings");

        // Step 3: Bob buys multiple NFTs
        uint256 totalCost = 0;
        for (uint256 i = 0; i < 3; i++) {
            totalCost += erc721Exchange.getBuyerSeesPrice(listingIds[i]);
        }

        vm.startPrank(bob);
        for (uint256 i = 0; i < 3; i++) {
            erc721Exchange.buyNFT{value: erc721Exchange.getBuyerSeesPrice(listingIds[i])}(listingIds[i]);
        }
        vm.stopPrank();
        console2.log("Step 3: Bob bought 3 NFTs");

        // Step 4: Verify Bob owns the NFTs
        for (uint256 i = 0; i < 3; i++) {
            assertNFTOwner(address(mockERC721), tokenIds[i], bob);
        }
        console2.log("Step 4: Ownership verified");

        // Step 5: Charlie buys remaining
        vm.startPrank(charlie);
        for (uint256 i = 3; i < 5; i++) {
            erc721Exchange.buyNFT{value: erc721Exchange.getBuyerSeesPrice(listingIds[i])}(listingIds[i]);
        }
        vm.stopPrank();

        for (uint256 i = 3; i < 5; i++) {
            assertNFTOwner(address(mockERC721), tokenIds[i], charlie);
        }
        console2.log("Step 5: Charlie bought remaining 2 NFTs");

        console2.log("=== Batch Listing and Buying: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 7: SECONDARY SALE WITH ROYALTIES
    // ============================================================================

    function test_E2E_SecondarySaleWithRoyalties() public {
        console2.log("\n=== Test: Secondary Sale with Royalties ===");

        // Step 1: Alice mints NFT with royalty support
        vm.prank(alice);
        mockERC721.mint(alice, 30);
        vm.prank(alice);
        mockERC721.setDefaultRoyalty(alice, uint96(ROYALTY_FEE_BPS));
        console2.log("Step 1: NFT with royalties minted");

        // Step 2: Primary sale - Alice to Bob (no royalty on primary)
        bytes32 listing1 = listERC721(alice, address(mockERC721), 30, NFT_PRICE, LISTING_DURATION);
        buyERC721(bob, listing1);
        assertNFTOwner(address(mockERC721), 30, bob);
        console2.log("Step 2: Primary sale complete");

        // Step 3: Secondary sale - Bob to Charlie (with royalty)
        BalanceSnapshot memory balancesBefore = snapshotBalances(charlie, bob, marketplaceWallet, alice);

        bytes32 listing2 = listERC721(bob, address(mockERC721), 30, NFT_PRICE * 2, LISTING_DURATION);
        buyERC721(charlie, listing2);

        BalanceSnapshot memory balancesAfter = snapshotBalances(charlie, bob, marketplaceWallet, alice);
        console2.log("Step 3: Secondary sale complete");

        // Step 4: Verify royalty payment to Alice
        uint256 salePrice = NFT_PRICE * 2;
        uint256 expectedRoyalty = (salePrice * ROYALTY_FEE_BPS) / 10000;
        uint256 takerFee = (salePrice * TAKER_FEE_BPS) / 10000;
        uint256 sellerGets = salePrice - expectedRoyalty;

        assertBalanceChanges(
            balancesBefore, balancesAfter, salePrice + takerFee + expectedRoyalty, sellerGets, takerFee, expectedRoyalty
        );
        console2.log("Step 4: Royalty payment verified");

        assertNFTOwner(address(mockERC721), 30, charlie);
        console2.log("=== Secondary Sale with Royalties: SUCCESS ===\n");
    }

    // ============================================================================
    // TEST 8: CROSS-TOKEN TRADING
    // ============================================================================

    function test_E2E_CrossTokenTrading() public {
        console2.log("\n=== Test: Cross-Token Trading (ERC721 + ERC1155) ===");

        // Setup: Alice has both token types
        vm.startPrank(alice);
        mockERC721.mint(alice, 40);
        mockERC1155.mint(alice, 2, 20);
        vm.stopPrank();

        // Step 1: List both tokens
        bytes32 erc721Listing = listERC721(alice, address(mockERC721), 40, 1 ether, LISTING_DURATION);
        bytes32 erc1155Listing = listERC1155(alice, address(mockERC1155), 2, 10, 0.5 ether, LISTING_DURATION);
        console2.log("Step 1: Both token types listed");

        // Step 2: Bob buys ERC721
        buyERC721(bob, erc721Listing);
        assertNFTOwner(address(mockERC721), 40, bob);
        console2.log("Step 2: ERC721 purchased");

        // Step 3: Charlie buys ERC1155
        buyERC1155(charlie, erc1155Listing, 5);
        assertERC1155Balance(address(mockERC1155), charlie, 2, 5);
        console2.log("Step 3: ERC1155 units purchased");

        // Step 4: Verify Alice still has remaining ERC1155
        assertERC1155Balance(address(mockERC1155), alice, 2, 15); // 20 - 5 = 15
        console2.log("Step 4: Remaining balances verified");

        console2.log("=== Cross-Token Trading: SUCCESS ===\n");
    }
}
