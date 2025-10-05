// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/libraries/BidManagementLib.sol";

/**
 * @title BidStorageTest
 * @notice Test contract to expose storage for testing
 */
contract BidStorageTest {
    BidManagementLib.BidStorage public bidStorage;

    function placeBid(BidManagementLib.BidPlacementParams memory params)
        external
        returns (BidManagementLib.BidPlacementResult memory)
    {
        return BidManagementLib.placeBid(bidStorage, params);
    }

    function processRefund(address bidder) external returns (uint256 refundAmount) {
        return BidManagementLib.processRefund(bidStorage, bidder);
    }

    function processAllRefunds(address excludeBidder) external returns (uint256 totalRefunded) {
        return BidManagementLib.processAllRefunds(bidStorage, excludeBidder);
    }

    function getBid(address bidder) external view returns (BidManagementLib.Bid memory) {
        return BidManagementLib.getBid(bidStorage, bidder);
    }

    function getHighestBid() external view returns (address bidder, uint256 amount) {
        return BidManagementLib.getHighestBid(bidStorage);
    }

    function getAllBidders() external view returns (address[] memory) {
        return BidManagementLib.getAllBidders(bidStorage);
    }

    function getTotalBids() external view returns (uint256) {
        return BidManagementLib.getTotalBids(bidStorage);
    }

    function getPendingRefund(address bidder) external view returns (uint256) {
        return BidManagementLib.getPendingRefund(bidStorage, bidder);
    }

    // Helper to fund contract for refunds
    receive() external payable {}
}

/**
 * @title BidManagementLibTest
 * @notice Comprehensive tests for BidManagementLib library functions
 */
contract BidManagementLibTest is Test {
    using BidManagementLib for *;

    BidStorageTest public bidStorageTest;

    address public bidder1 = address(0x1);
    address public bidder2 = address(0x2);
    address public bidder3 = address(0x3);

    function setUp() public {
        bidStorageTest = new BidStorageTest();

        // Fund test accounts
        vm.deal(bidder1, 10 ether);
        vm.deal(bidder2, 10 ether);
        vm.deal(bidder3, 10 ether);
        vm.deal(address(bidStorageTest), 10 ether);
    }

    // ============================================================================
    // BID PLACEMENT TESTS
    // ============================================================================

    function testPlaceBid_FirstBid_Success() public {
        BidManagementLib.BidPlacementParams memory params = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });

        BidManagementLib.BidPlacementResult memory result = bidStorageTest.placeBid(params);

        assertTrue(result.success);
        assertEq(result.previousHighestBidder, address(0));
        assertEq(result.previousHighestBid, 0);
        assertFalse(result.needsRefund);
        assertEq(result.refundAmount, 0);
        assertEq(result.errorMessage, "");

        // Check storage state
        (address highestBidder, uint256 highestAmount) = bidStorageTest.getHighestBid();
        assertEq(highestBidder, bidder1);
        assertEq(highestAmount, 1 ether);
    }

    function testPlaceBid_InvalidBidder() public {
        BidManagementLib.BidPlacementParams memory params = BidManagementLib.BidPlacementParams({
            bidder: address(0),
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });

        BidManagementLib.BidPlacementResult memory result = bidStorageTest.placeBid(params);

        assertFalse(result.success);
        assertEq(result.errorMessage, "Invalid bidder address");
    }

    function testPlaceBid_SecondBid_Success() public {
        // Place first bid
        BidManagementLib.BidPlacementParams memory params1 = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });
        bidStorageTest.placeBid(params1);

        // Place second bid
        BidManagementLib.BidPlacementParams memory params2 = BidManagementLib.BidPlacementParams({
            bidder: bidder2,
            bidAmount: 2 ether,
            currentHighestBid: 1 ether,
            currentHighestBidder: bidder1,
            isFirstBid: false
        });

        BidManagementLib.BidPlacementResult memory result = bidStorageTest.placeBid(params2);

        assertTrue(result.success);
        assertEq(result.previousHighestBidder, bidder1);
        assertEq(result.previousHighestBid, 1 ether);
        assertTrue(result.needsRefund);
        assertEq(result.refundAmount, 1 ether);

        // Check storage state
        (address highestBidder, uint256 highestAmount) = bidStorageTest.getHighestBid();
        assertEq(highestBidder, bidder2);
        assertEq(highestAmount, 2 ether);
    }

    function testPlaceBid_UpdateExistingBid() public {
        // Place first bid
        BidManagementLib.BidPlacementParams memory params1 = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });
        bidStorageTest.placeBid(params1);

        // Update same bidder's bid
        BidManagementLib.BidPlacementParams memory params2 = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 2 ether,
            currentHighestBid: 1 ether,
            currentHighestBidder: bidder1,
            isFirstBid: false
        });

        BidManagementLib.BidPlacementResult memory result = bidStorageTest.placeBid(params2);

        assertTrue(result.success);
        // Should not need refund since same bidder
        assertFalse(result.needsRefund);

        // Check storage state - bidder1 should now have 3 ether total bid (1 + 2)
        (address highestBidder, uint256 highestAmount) = bidStorageTest.getHighestBid();
        assertEq(highestBidder, bidder1);
        assertEq(highestAmount, 3 ether);
    }

    // ============================================================================
    // REFUND TESTS
    // ============================================================================

    function testRefundBidder_Success() public {
        // Place bids to create refund scenario
        BidManagementLib.BidPlacementParams memory params1 = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });
        bidStorageTest.placeBid(params1);

        BidManagementLib.BidPlacementParams memory params2 = BidManagementLib.BidPlacementParams({
            bidder: bidder2,
            bidAmount: 2 ether,
            currentHighestBid: 1 ether,
            currentHighestBidder: bidder1,
            isFirstBid: false
        });
        bidStorageTest.placeBid(params2);

        // Check pending refund
        uint256 pendingRefund = bidStorageTest.getPendingRefund(bidder1);
        assertEq(pendingRefund, 1 ether);

        // Process refund for bidder1
        uint256 refundAmount = bidStorageTest.processRefund(bidder1);

        assertEq(refundAmount, 1 ether);

        // Check refund is cleared
        assertEq(bidStorageTest.getPendingRefund(bidder1), 0);
    }

    function testProcessRefund_NoPendingRefund() public {
        uint256 refundAmount = bidStorageTest.processRefund(bidder1);

        assertEq(refundAmount, 0);
    }

    function testRefundAllBidders() public {
        // Create multiple bids to generate refunds
        BidManagementLib.BidPlacementParams memory params1 = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });
        bidStorageTest.placeBid(params1);

        BidManagementLib.BidPlacementParams memory params2 = BidManagementLib.BidPlacementParams({
            bidder: bidder2,
            bidAmount: 2 ether,
            currentHighestBid: 1 ether,
            currentHighestBidder: bidder1,
            isFirstBid: false
        });
        bidStorageTest.placeBid(params2);

        BidManagementLib.BidPlacementParams memory params3 = BidManagementLib.BidPlacementParams({
            bidder: bidder3,
            bidAmount: 3 ether,
            currentHighestBid: 2 ether,
            currentHighestBidder: bidder2,
            isFirstBid: false
        });
        bidStorageTest.placeBid(params3);

        // Process refunds for all bidders except winner (bidder3)
        uint256 totalRefunded = bidStorageTest.processAllRefunds(bidder3);

        assertEq(totalRefunded, 3 ether); // 1 ether + 2 ether
    }

    // ============================================================================
    // GETTER FUNCTION TESTS
    // ============================================================================

    function testGetBidInfo() public {
        BidManagementLib.BidPlacementParams memory params = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });
        bidStorageTest.placeBid(params);

        BidManagementLib.Bid memory bid = bidStorageTest.getBid(bidder1);

        assertEq(bid.bidder, bidder1);
        assertEq(bid.amount, 1 ether);
        assertTrue(bid.isActive);
        assertFalse(bid.isRefunded);
        assertTrue(bid.timestamp > 0);
    }

    function testGetHighestBid() public {
        BidManagementLib.BidPlacementParams memory params = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });
        bidStorageTest.placeBid(params);

        (address highestBidder, uint256 highestAmount) = bidStorageTest.getHighestBid();

        assertEq(highestBidder, bidder1);
        assertEq(highestAmount, 1 ether);
    }

    function testGetAllBidders() public {
        // Place multiple bids
        BidManagementLib.BidPlacementParams memory params1 = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });
        bidStorageTest.placeBid(params1);

        BidManagementLib.BidPlacementParams memory params2 = BidManagementLib.BidPlacementParams({
            bidder: bidder2,
            bidAmount: 2 ether,
            currentHighestBid: 1 ether,
            currentHighestBidder: bidder1,
            isFirstBid: false
        });
        bidStorageTest.placeBid(params2);

        address[] memory bidders = bidStorageTest.getAllBidders();

        assertEq(bidders.length, 2);
        assertEq(bidders[0], bidder1);
        assertEq(bidders[1], bidder2);
    }

    function testGetTotalBids() public {
        assertEq(bidStorageTest.getTotalBids(), 0);

        // Place first bid
        BidManagementLib.BidPlacementParams memory params1 = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });
        bidStorageTest.placeBid(params1);

        assertEq(bidStorageTest.getTotalBids(), 1);

        // Place second bid
        BidManagementLib.BidPlacementParams memory params2 = BidManagementLib.BidPlacementParams({
            bidder: bidder2,
            bidAmount: 2 ether,
            currentHighestBid: 1 ether,
            currentHighestBidder: bidder1,
            isFirstBid: false
        });
        bidStorageTest.placeBid(params2);

        assertEq(bidStorageTest.getTotalBids(), 2);
    }

    function testGetPendingRefund() public {
        assertEq(bidStorageTest.getPendingRefund(bidder1), 0);

        // Create refund scenario
        BidManagementLib.BidPlacementParams memory params1 = BidManagementLib.BidPlacementParams({
            bidder: bidder1,
            bidAmount: 1 ether,
            currentHighestBid: 0,
            currentHighestBidder: address(0),
            isFirstBid: true
        });
        bidStorageTest.placeBid(params1);

        BidManagementLib.BidPlacementParams memory params2 = BidManagementLib.BidPlacementParams({
            bidder: bidder2,
            bidAmount: 2 ether,
            currentHighestBid: 1 ether,
            currentHighestBidder: bidder1,
            isFirstBid: false
        });
        bidStorageTest.placeBid(params2);

        assertEq(bidStorageTest.getPendingRefund(bidder1), 1 ether);
        assertEq(bidStorageTest.getPendingRefund(bidder2), 0);
    }
}
