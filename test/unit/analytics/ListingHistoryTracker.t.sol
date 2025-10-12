// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/core/analytics/ListingHistoryTracker.sol";
import "src/core/access/MarketplaceAccessControl.sol";
import "src/errors/AnalyticsErrors.sol";
import "test/mocks/MockERC721.sol";
import "test/mocks/MockERC1155.sol";
import "test/utils/TestHelpers.sol";

contract ListingHistoryTrackerTest is Test, TestHelpers {
    ListingHistoryTracker public tracker;
    MarketplaceAccessControl public accessControl;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    address public admin = makeAddr("admin");
    address public user = makeAddr("user");
    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");

    function setUp() public {
        // Deploy access control - admin will automatically get ADMIN_ROLE
        vm.prank(admin);
        accessControl = new MarketplaceAccessControl();

        // Admin already has ADMIN_ROLE from constructor, now grant other roles
        bytes32 operatorRole = accessControl.OPERATOR_ROLE();
        bytes32 pauserRole = accessControl.PAUSER_ROLE();

        vm.prank(admin);
        accessControl.grantRoleWithReason(operatorRole, admin, "Test setup");

        vm.prank(admin);
        accessControl.grantRoleWithReason(pauserRole, admin, "Test setup");

        // Deploy tracker
        vm.prank(admin);
        tracker = new ListingHistoryTracker(address(accessControl), admin);

        // Deploy mock NFTs
        mockERC721 = new MockERC721("Test721", "T721");
        mockERC1155 = new MockERC1155("Test1155", "T1155");

        // Mint test NFTs
        mockERC721.mint(seller, 1);
        mockERC1155.mint(seller, 1, 10);
    }

    function testRecordTransaction() public {
        bytes32 listingId = keccak256("listing1");

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.LISTING_CREATED,
            seller,
            1 ether
        );

        // Verify transaction was recorded
        ListingHistoryTracker.TransactionRecord[] memory history = tracker
            .getNFTHistory(address(mockERC721), 1, 10);

        assertEq(history.length, 1);
        assertEq(history[0].listingId, listingId);
        assertEq(
            uint256(history[0].txType),
            uint256(ListingHistoryTracker.TransactionType.LISTING_CREATED)
        );
        assertEq(history[0].price, 1 ether);
    }

    function testGetNFTHistory() public {
        bytes32 listingId = keccak256("listing1");

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1.5 ether
        );

        // Verify history retrieval
        ListingHistoryTracker.TransactionRecord[] memory history = tracker
            .getNFTHistory(address(mockERC721), 1, 10);

        assertEq(history.length, 1);
        assertEq(history[0].price, 1.5 ether);
        assertEq(
            uint256(history[0].txType),
            uint256(ListingHistoryTracker.TransactionType.SALE_COMPLETED)
        );
    }

    function testAccessControl() public {
        bytes32 listingId = keccak256("listing1");

        // Non-admin should not be able to record transactions
        vm.prank(user);
        vm.expectRevert();
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.LISTING_CREATED,
            seller,
            1 ether
        );
    }

    function testGetCollectionPriceHistory() public {
        bytes32 listingId = keccak256("listing1");

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1 ether
        );

        // Test price history retrieval
        ListingHistoryTracker.PricePoint[] memory priceHistory = tracker
            .getCollectionPriceHistory(address(mockERC721), 10);

        assertEq(priceHistory.length, 1);
        assertEq(priceHistory[0].price, 1 ether);
    }

    // ============================================================================
    // NEW FEATURE TESTS
    // ============================================================================

    function testGetGlobalStats() public {
        // Record some transactions to update global stats
        bytes32 listingId1 = keccak256("listing1");
        bytes32 listingId2 = keccak256("listing2");

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId1,
            ListingHistoryTracker.TransactionType.LISTING_CREATED,
            seller,
            1 ether
        );

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId1,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1.5 ether
        );

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC1155),
            1,
            listingId2,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            buyer,
            2 ether
        );

        // Get global stats
        ListingHistoryTracker.MarketplaceStats memory stats = tracker
            .getGlobalStats();

        assertEq(stats.totalListings, 1);
        assertEq(stats.totalSales, 2);
        assertEq(stats.totalVolume, 3.5 ether);
        assertEq(stats.averageSalePrice, 1.75 ether);
        assertTrue(stats.lastUpdated > 0);
    }

    function testGetCollectionStats() public {
        bytes32 listingId = keccak256("listing1");

        // Record transactions for collection
        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.LISTING_CREATED,
            seller,
            1 ether
        );

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1.5 ether
        );

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            2,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            2 ether
        );

        // Get collection stats
        ListingHistoryTracker.CollectionStats memory stats = tracker
            .getCollectionStats(address(mockERC721));

        assertEq(stats.totalListings, 1);
        assertEq(stats.totalSales, 2);
        assertEq(stats.totalVolume, 3.5 ether);
        assertEq(stats.averagePrice, 1.75 ether);
        assertEq(stats.highestSale, 2 ether);
        assertEq(stats.activeListings, 0); // 1 created - 2 sold = 0 active
        assertTrue(stats.lastUpdated > 0);
    }

    function testGetUserStats() public {
        bytes32 listingId = keccak256("listing1");

        // Record transactions for user
        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.LISTING_CREATED,
            seller,
            1 ether
        );

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1.5 ether
        );

        // Get user stats
        ListingHistoryTracker.UserStats memory stats = tracker.getUserStats(
            seller
        );

        assertEq(stats.totalListings, 1);
        assertEq(stats.totalSales, 1);
        assertEq(stats.volumeSold, 1.5 ether);
        assertEq(stats.averageSalePrice, 1.5 ether);
        assertTrue(stats.firstActivity > 0);
        assertTrue(stats.lastActivity > 0);
    }

    function testGetDailyVolume() public {
        bytes32 listingId = keccak256("listing1");

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1 ether
        );

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC1155),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            buyer,
            2 ether
        );

        // Get today's volume
        uint256 today = block.timestamp / 1 days;
        ListingHistoryTracker.DailyVolume memory volume = tracker
            .getDailyVolume(today);

        assertEq(volume.volume, 3 ether);
        assertEq(volume.transactions, 2);
        assertEq(volume.averagePrice, 1.5 ether);
    }

    function testGetAllTrackedCollections() public {
        bytes32 listingId1 = keccak256("listing1");
        bytes32 listingId2 = keccak256("listing2");

        // Initially no collections tracked
        address[] memory collections = tracker.getAllTrackedCollections();
        assertEq(collections.length, 0);

        // Record transaction for first collection
        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId1,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1 ether
        );

        // Record transaction for second collection
        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC1155),
            1,
            listingId2,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            buyer,
            2 ether
        );

        // Now should have 2 collections tracked
        collections = tracker.getAllTrackedCollections();
        assertEq(collections.length, 2);
        assertTrue(
            collections[0] == address(mockERC721) ||
                collections[1] == address(mockERC721)
        );
        assertTrue(
            collections[0] == address(mockERC1155) ||
                collections[1] == address(mockERC1155)
        );
    }

    function testGetTrackedCollectionsCount() public {
        bytes32 listingId = keccak256("listing1");

        // Initially 0 collections
        assertEq(tracker.getTrackedCollectionsCount(), 0);

        // Record transaction
        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1 ether
        );

        // Now 1 collection
        assertEq(tracker.getTrackedCollectionsCount(), 1);
    }

    function testGetCollectionStatsBatch() public {
        bytes32 listingId1 = keccak256("listing1");
        bytes32 listingId2 = keccak256("listing2");

        // Record transactions for multiple collections
        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId1,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1 ether
        );

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC1155),
            1,
            listingId2,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            buyer,
            2 ether
        );

        // Get batch stats
        address[] memory collections = new address[](2);
        collections[0] = address(mockERC721);
        collections[1] = address(mockERC1155);

        ListingHistoryTracker.CollectionStats[] memory stats = tracker
            .getCollectionStatsBatch(collections);

        assertEq(stats.length, 2);
        assertEq(stats[0].totalSales, 1);
        assertEq(stats[0].totalVolume, 1 ether);
        assertEq(stats[1].totalSales, 1);
        assertEq(stats[1].totalVolume, 2 ether);
    }

    function testGetCollectionStatsBatchLimitExceeded() public {
        // Create array with more than MAX_BATCH_SIZE collections
        address[] memory collections = new address[](101); // MAX_BATCH_SIZE is 100
        for (uint256 i = 0; i < 101; i++) {
            collections[i] = address(uint160(i + 1));
        }

        vm.expectRevert(AnalyticsErrors.Analytics__BatchLimitExceeded.selector);
        tracker.getCollectionStatsBatch(collections);
    }

    function testPauseUnpause() public {
        bytes32 listingId = keccak256("listing1");

        // Initially not paused
        assertFalse(tracker.paused());

        // Pause the contract
        vm.prank(admin);
        tracker.pause();
        assertTrue(tracker.paused());

        // Should not be able to record transactions when paused
        vm.prank(admin);
        vm.expectRevert();
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1 ether
        );

        // Unpause the contract
        vm.prank(admin);
        tracker.unpause();
        assertFalse(tracker.paused());

        // Should be able to record transactions again
        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1 ether
        );
    }

    function testOnlyOwnerCanPause() public {
        // Non-owner should not be able to pause
        vm.prank(user);
        vm.expectRevert();
        tracker.pause();

        vm.prank(user);
        vm.expectRevert();
        tracker.unpause();
    }

    function testAutoRegisterCollection() public {
        bytes32 listingId = keccak256("listing1");
        address newCollection = makeAddr("newCollection");

        // Initially collection is not tracked
        address[] memory collections = tracker.getAllTrackedCollections();
        assertEq(collections.length, 0);

        // Record transaction for new collection
        vm.prank(admin);
        tracker.recordTransaction(
            newCollection,
            1,
            listingId,
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1 ether
        );

        // Collection should now be auto-registered
        collections = tracker.getAllTrackedCollections();
        assertEq(collections.length, 1);
        assertEq(collections[0], newCollection);

        // Should be able to get stats for the collection
        ListingHistoryTracker.CollectionStats memory stats = tracker
            .getCollectionStats(newCollection);
        assertEq(stats.totalSales, 1);
        assertEq(stats.totalVolume, 1 ether);
    }

    function testGasOptimizationUncheckedArithmetic() public {
        bytes32 listingId = keccak256("listing1");

        // Record many transactions to test gas optimization
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(admin);
            tracker.recordTransaction(
                address(mockERC721),
                i,
                listingId,
                ListingHistoryTracker.TransactionType.SALE_COMPLETED,
                seller,
                1 ether
            );
        }

        // Verify stats are correct
        ListingHistoryTracker.CollectionStats memory stats = tracker
            .getCollectionStats(address(mockERC721));
        assertEq(stats.totalSales, 10);
        assertEq(stats.totalVolume, 10 ether);

        ListingHistoryTracker.MarketplaceStats memory globalStats = tracker
            .getGlobalStats();
        assertEq(globalStats.totalSales, 10);
        assertEq(globalStats.totalVolume, 10 ether);
    }

    function testErrorHandling() public {
        // Test invalid collection address
        vm.prank(admin);
        vm.expectRevert(AnalyticsErrors.Analytics__InvalidCollection.selector);
        tracker.recordTransaction(
            address(0),
            1,
            keccak256("listing1"),
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1 ether
        );

        // Test invalid user (non-operator)
        vm.prank(user);
        vm.expectRevert(AnalyticsErrors.Analytics__InvalidUser.selector);
        tracker.recordTransaction(
            address(mockERC721),
            1,
            keccak256("listing1"),
            ListingHistoryTracker.TransactionType.SALE_COMPLETED,
            seller,
            1 ether
        );
    }
}
