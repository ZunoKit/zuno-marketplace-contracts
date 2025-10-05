// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/core/auction/EnglishAuction.sol";
import "src/core/auction/DutchAuction.sol";
import "src/core/auction/AuctionFactory.sol";
import "src/interfaces/IAuction.sol";
import "src/errors/AuctionErrors.sol";
import "../../mocks/MockERC721.sol";

/**
 * @title AuctionCancellation Test
 * @notice Tests to verify auction cancellation functionality and refund mechanisms
 */
contract AuctionCancellationTest is Test {
    // Contracts
    AuctionFactory public auctionFactory;
    EnglishAuction public englishAuction;
    DutchAuction public dutchAuction;
    MockERC721 public mockERC721;

    // Test addresses
    address public constant MARKETPLACE_WALLET = address(0x1);
    address public constant SELLER = address(0x2);
    address public constant BIDDER1 = address(0x3);
    address public constant BIDDER2 = address(0x4);
    address public constant BIDDER3 = address(0x5);

    // Constants
    uint256 public constant DEFAULT_START_PRICE = 1 ether;
    uint256 public constant DEFAULT_RESERVE_PRICE = 0.5 ether;
    uint256 public constant DEFAULT_DURATION = 1 days;
    uint256 public constant DEFAULT_PRICE_DROP = 1000; // 10% per hour

    function setUp() public {
        // Deploy contracts
        mockERC721 = new MockERC721("Test NFT", "TEST");
        auctionFactory = new AuctionFactory(MARKETPLACE_WALLET);
        englishAuction = auctionFactory.englishAuction();
        dutchAuction = auctionFactory.dutchAuction();

        // Mint test NFTs
        mockERC721.mint(SELLER, 1);
        mockERC721.mint(SELLER, 2);
        mockERC721.mint(SELLER, 3);

        // Give test accounts some ETH
        vm.deal(BIDDER1, 10 ether);
        vm.deal(BIDDER2, 10 ether);
        vm.deal(BIDDER3, 10 ether);
        vm.deal(SELLER, 1 ether);
    }

    // ============================================================================
    // ENGLISH AUCTION CANCELLATION TESTS
    // ============================================================================

    function test_EnglishAuction_CancelWithoutBids_Success() public {
        // Create auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createEnglishAuction(
            address(mockERC721), 1, 1, DEFAULT_START_PRICE, DEFAULT_RESERVE_PRICE, DEFAULT_DURATION
        );

        // Cancel auction (should succeed - no bids)
        auctionFactory.cancelAuction(auctionId);
        vm.stopPrank();

        // Verify auction is cancelled
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        assertEq(uint256(auction.status), uint256(IAuction.AuctionStatus.CANCELLED));
    }

    function test_EnglishAuction_CancelWithBids_ShouldRevert() public {
        // Create auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createEnglishAuction(
            address(mockERC721), 1, 1, DEFAULT_START_PRICE, DEFAULT_RESERVE_PRICE, DEFAULT_DURATION
        );
        vm.stopPrank();

        // Place a bid
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: DEFAULT_START_PRICE}(auctionId);

        // Try to cancel auction (should fail - has bids)
        vm.prank(SELLER);
        vm.expectRevert(Auction__CannotCancelWithBids.selector);
        auctionFactory.cancelAuction(auctionId);
    }

    // ============================================================================
    // DUTCH AUCTION CANCELLATION TESTS
    // ============================================================================

    function test_DutchAuction_Cancel_Success() public {
        // Create auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createDutchAuction(
            address(mockERC721), 1, 1, DEFAULT_START_PRICE, DEFAULT_RESERVE_PRICE, DEFAULT_DURATION, DEFAULT_PRICE_DROP
        );

        // Cancel auction
        auctionFactory.cancelAuction(auctionId);
        vm.stopPrank();

        // Verify auction is cancelled
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        assertEq(uint256(auction.status), uint256(IAuction.AuctionStatus.CANCELLED));
    }

    // ============================================================================
    // MULTIPLE BIDDING AND REFUND TESTS
    // ============================================================================

    function test_MultipleBidsFromSameUser_RefundsAccumulate() public {
        // Create auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createEnglishAuction(
            address(mockERC721),
            1,
            1,
            DEFAULT_START_PRICE,
            0, // No reserve
            DEFAULT_DURATION
        );
        vm.stopPrank();

        // BIDDER1 places first bid
        uint256 firstBid = DEFAULT_START_PRICE;
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: firstBid}(auctionId);

        // BIDDER2 outbids BIDDER1
        uint256 secondBid = firstBid + 0.1 ether;
        vm.prank(BIDDER2);
        auctionFactory.placeBid{value: secondBid}(auctionId);

        // BIDDER1 bids again (higher)
        uint256 thirdBid = secondBid + 0.1 ether;
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: thirdBid}(auctionId);

        // BIDDER2 bids again (even higher)
        uint256 fourthBid = thirdBid + 0.1 ether;
        vm.prank(BIDDER2);
        auctionFactory.placeBid{value: fourthBid}(auctionId);

        // BIDDER1 bids one more time
        uint256 fifthBid = fourthBid + 0.1 ether;
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: fifthBid}(auctionId);

        // Check pending refunds
        uint256 bidder1Refund = auctionFactory.getPendingRefund(auctionId, BIDDER1);
        uint256 bidder2Refund = auctionFactory.getPendingRefund(auctionId, BIDDER2);

        // BIDDER1 should have NO refunds because they are currently the highest bidder
        // When a user becomes highest bidder again, their pending refunds are cleared
        // This prevents the double-withdraw bug
        assertEq(bidder1Refund, 0, "BIDDER1 should have NO refunds when they are highest bidder");

        // BIDDER2 should have refund only from fourth bid (1.3 ETH)
        // Their second bid (1.1 ETH) was already refunded when they became highest bidder
        assertEq(bidder2Refund, fourthBid, "BIDDER2 should have refund from fourth bid only");

        // Test withdrawals
        uint256 bidder2BalanceBefore = BIDDER2.balance;

        // BIDDER1 cannot withdraw because they have no pending refunds (they are highest bidder)
        vm.prank(BIDDER1);
        vm.expectRevert(Auction__NoBidToRefund.selector);
        auctionFactory.withdrawBid(auctionId);

        // BIDDER2 can withdraw their refunds
        vm.prank(BIDDER2);
        auctionFactory.withdrawBid(auctionId);

        // Verify BIDDER2 withdrawal
        assertEq(BIDDER2.balance, bidder2BalanceBefore + bidder2Refund, "BIDDER2 should receive all refunds");

        // Verify BIDDER2 refunds are cleared
        assertEq(auctionFactory.getPendingRefund(auctionId, BIDDER2), 0, "BIDDER2 refunds should be cleared");
    }

    function test_AuctionSettlement_RefundsAllLosers() public {
        // Create auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId =
            auctionFactory.createEnglishAuction(address(mockERC721), 1, 1, DEFAULT_START_PRICE, 0, DEFAULT_DURATION);
        vm.stopPrank();

        // Multiple bidders place bids
        uint256 bid1 = DEFAULT_START_PRICE;
        uint256 bid2 = bid1 + 0.1 ether;
        uint256 bid3 = bid2 + 0.1 ether;

        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: bid1}(auctionId);

        vm.prank(BIDDER2);
        auctionFactory.placeBid{value: bid2}(auctionId);

        vm.prank(BIDDER3);
        auctionFactory.placeBid{value: bid3}(auctionId);

        // Fast forward to end auction
        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        // Record balances before settlement
        uint256 bidder1BalanceBefore = BIDDER1.balance;
        uint256 bidder2BalanceBefore = BIDDER2.balance;
        uint256 sellerBalanceBefore = SELLER.balance;

        // Settle auction
        auctionFactory.settleAuction(auctionId);

        // Verify BIDDER3 won the auction
        assertEq(mockERC721.ownerOf(1), BIDDER3, "BIDDER3 should win the auction");

        // Verify seller received payment (minus fees)
        assertGt(SELLER.balance, sellerBalanceBefore, "Seller should receive payment");

        // Verify losing bidders can withdraw refunds
        vm.prank(BIDDER1);
        auctionFactory.withdrawBid(auctionId);
        assertEq(BIDDER1.balance, bidder1BalanceBefore + bid1, "BIDDER1 should get refund");

        vm.prank(BIDDER2);
        auctionFactory.withdrawBid(auctionId);
        assertEq(BIDDER2.balance, bidder2BalanceBefore + bid2, "BIDDER2 should get refund");
    }

    function test_ReserveNotMet_RefundsAllBidders() public {
        uint256 highReserve = 5 ether;

        // Create auction with high reserve
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createEnglishAuction(
            address(mockERC721),
            1,
            1,
            DEFAULT_START_PRICE,
            highReserve, // High reserve
            DEFAULT_DURATION
        );
        vm.stopPrank();

        // Place bids below reserve
        uint256 bid1 = DEFAULT_START_PRICE;
        uint256 bid2 = bid1 + 0.5 ether;

        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: bid1}(auctionId);

        vm.prank(BIDDER2);
        auctionFactory.placeBid{value: bid2}(auctionId);

        // Fast forward to end auction
        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        // Record balances
        uint256 bidder1BalanceBefore = BIDDER1.balance;
        uint256 bidder2BalanceBefore = BIDDER2.balance;

        // Settle auction (should fail due to reserve not met)
        auctionFactory.settleAuction(auctionId);

        // Verify auction ended without sale
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        assertEq(uint256(auction.status), uint256(IAuction.AuctionStatus.ENDED));

        // Verify NFT still belongs to seller
        assertEq(mockERC721.ownerOf(1), SELLER, "Seller should still own NFT");

        // Verify all bidders can withdraw refunds
        vm.prank(BIDDER1);
        auctionFactory.withdrawBid(auctionId);
        assertEq(BIDDER1.balance, bidder1BalanceBefore + bid1, "BIDDER1 should get full refund");

        vm.prank(BIDDER2);
        auctionFactory.withdrawBid(auctionId);
        assertEq(BIDDER2.balance, bidder2BalanceBefore + bid2, "BIDDER2 should get full refund");
    }

    // ============================================================================
    // EDGE CASE TESTS
    // ============================================================================

    function test_WithdrawBid_NoRefund_ShouldRevert() public {
        // Create auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId =
            auctionFactory.createEnglishAuction(address(mockERC721), 1, 1, DEFAULT_START_PRICE, 0, DEFAULT_DURATION);
        vm.stopPrank();

        // Try to withdraw without any bids
        vm.prank(BIDDER1);
        vm.expectRevert(Auction__NoBidToRefund.selector);
        auctionFactory.withdrawBid(auctionId);
    }

    function test_WithdrawBid_AlreadyWithdrawn_ShouldRevert() public {
        // Create auction and place bid
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId =
            auctionFactory.createEnglishAuction(address(mockERC721), 1, 1, DEFAULT_START_PRICE, 0, DEFAULT_DURATION);
        vm.stopPrank();

        // Place bids
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: DEFAULT_START_PRICE}(auctionId);

        vm.prank(BIDDER2);
        auctionFactory.placeBid{value: DEFAULT_START_PRICE + 0.1 ether}(auctionId);

        // Withdraw once
        vm.prank(BIDDER1);
        auctionFactory.withdrawBid(auctionId);

        // Try to withdraw again
        vm.prank(BIDDER1);
        vm.expectRevert(Auction__NoBidToRefund.selector);
        auctionFactory.withdrawBid(auctionId);
    }

    function test_MultipleBidsFromSameUser_NoPendingRefundsWhenHighest() public {
        // Create auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId =
            auctionFactory.createEnglishAuction(address(mockERC721), 1, 1, DEFAULT_START_PRICE, 0, DEFAULT_DURATION);
        vm.stopPrank();

        // User A bids first
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: DEFAULT_START_PRICE}(auctionId);

        // User B outbids A
        vm.prank(BIDDER2);
        auctionFactory.placeBid{value: DEFAULT_START_PRICE + 0.1 ether}(auctionId);

        // Verify A has pending refunds
        uint256 refundBeforeRebid = auctionFactory.getPendingRefund(auctionId, BIDDER1);
        assertEq(refundBeforeRebid, DEFAULT_START_PRICE, "BIDDER1 should have pending refund");

        // User A bids again and becomes highest bidder
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: DEFAULT_START_PRICE + 0.2 ether}(auctionId);

        // 🔥 CRITICAL TEST: A should NOT have pending refunds when they're highest bidder
        uint256 refundAfterRebid = auctionFactory.getPendingRefund(auctionId, BIDDER1);
        assertEq(refundAfterRebid, 0, "BIDDER1 should NOT have pending refunds when highest bidder");

        // Verify A is indeed the highest bidder
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        assertEq(auction.highestBidder, BIDDER1, "BIDDER1 should be highest bidder");
        assertEq(auction.highestBid, DEFAULT_START_PRICE + 0.2 ether, "Highest bid should be correct");

        // Verify B has pending refunds
        uint256 bidder2Refund = auctionFactory.getPendingRefund(auctionId, BIDDER2);
        assertEq(bidder2Refund, DEFAULT_START_PRICE + 0.1 ether, "BIDDER2 should have pending refund");
    }

    function test_PreventDoubleWithdrawBug() public {
        // Create auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId =
            auctionFactory.createEnglishAuction(address(mockERC721), 1, 1, DEFAULT_START_PRICE, 0, DEFAULT_DURATION);
        vm.stopPrank();

        // Scenario that would cause the bug
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: 1 ether}(auctionId);

        vm.prank(BIDDER2);
        auctionFactory.placeBid{value: 1.5 ether}(auctionId);

        // BIDDER1 bids again and becomes highest
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: 2 ether}(auctionId);

        // BIDDER1 should NOT be able to withdraw anything
        vm.prank(BIDDER1);
        vm.expectRevert(Auction__NoBidToRefund.selector);
        auctionFactory.withdrawBid(auctionId);

        // But BIDDER2 should be able to withdraw
        uint256 bidder2BalanceBefore = BIDDER2.balance;
        vm.prank(BIDDER2);
        auctionFactory.withdrawBid(auctionId);
        assertEq(BIDDER2.balance, bidder2BalanceBefore + 1.5 ether, "BIDDER2 should get refund");
    }

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================

    receive() external payable {}
}
