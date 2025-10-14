// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/core/analytics/ListingHistoryTracker.sol";
import "src/core/access/MarketplaceAccessControl.sol";
import "test/mocks/MockERC721.sol";
import "test/mocks/MockERC1155.sol";
import "test/utils/TestHelpers.sol";
import "src/errors/NFTExchangeErrors.sol";

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
        accessControl.grantRoleSimple(operatorRole, admin);

        vm.prank(admin);
        accessControl.grantRoleSimple(pauserRole, admin);

        // Deploy tracker
        vm.prank(admin);
        tracker = new ListingHistoryTracker(address(accessControl));

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
            address(mockERC721), 1, listingId, ListingHistoryTracker.TransactionType.LISTING_CREATED, seller, 1 ether
        );

        // Verify transaction was recorded
        ListingHistoryTracker.TransactionRecord[] memory history = tracker.getNFTHistory(address(mockERC721), 1, 10);

        assertEq(history.length, 1);
        assertEq(history[0].listingId, listingId);
        assertEq(uint256(history[0].txType), uint256(ListingHistoryTracker.TransactionType.LISTING_CREATED));
        assertEq(history[0].price, 1 ether);
    }

    function testGetNFTHistory() public {
        bytes32 listingId = keccak256("listing1");

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721), 1, listingId, ListingHistoryTracker.TransactionType.SALE_COMPLETED, seller, 1.5 ether
        );

        // Verify history retrieval
        ListingHistoryTracker.TransactionRecord[] memory history = tracker.getNFTHistory(address(mockERC721), 1, 10);

        assertEq(history.length, 1);
        assertEq(history[0].price, 1.5 ether);
        assertEq(uint256(history[0].txType), uint256(ListingHistoryTracker.TransactionType.SALE_COMPLETED));
    }

    function testAccessControl() public {
        bytes32 listingId = keccak256("listing1");

        // Non-admin should not be able to record transactions
        vm.prank(user);
        vm.expectRevert(NFTExchange__NotTheOwner.selector);
        tracker.recordTransaction(
            address(mockERC721), 1, listingId, ListingHistoryTracker.TransactionType.LISTING_CREATED, seller, 1 ether
        );
    }

    function testGetCollectionPriceHistory() public {
        bytes32 listingId = keccak256("listing1");

        vm.prank(admin);
        tracker.recordTransaction(
            address(mockERC721), 1, listingId, ListingHistoryTracker.TransactionType.SALE_COMPLETED, seller, 1 ether
        );

        // Test price history retrieval
        ListingHistoryTracker.PricePoint[] memory priceHistory =
            tracker.getCollectionPriceHistory(address(mockERC721), 10);

        assertEq(priceHistory.length, 1);
        assertEq(priceHistory[0].price, 1 ether);
    }
}
