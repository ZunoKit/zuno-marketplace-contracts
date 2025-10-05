// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {DutchAuction} from "src/core/auction/DutchAuction.sol";
import {IAuction} from "src/interfaces/IAuction.sol";
import {AuctionTestHelpers} from "../utils/AuctionTestHelpers.sol";
import "src/errors/AuctionErrors.sol";

/**
 * @title DutchAuctionCoverageBoostTest
 * @notice Additional tests to boost DutchAuction branch coverage to >90%
 * @dev Focuses on edge cases and conditional logic paths
 */
contract DutchAuctionCoverageBoostTest is AuctionTestHelpers {
    function setUp() public {
        setUpAuctionTests();
    }

    // ============================================================================
    // PRICE CALCULATION EDGE CASES
    // ============================================================================

    function test_GetCurrentPrice_ExactlyAtReservePrice() public {
        bytes32 auctionId = createBasicDutchAuction(1);

        // Get auction details
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);

        // Calculate time when price reaches reserve manually
        // Using the same logic as in DutchAuction.getTimeToReservePrice
        uint256 totalDrop = auction.startPrice - auction.reservePrice;
        uint256 dropPerSecond = (auction.startPrice * DEFAULT_PRICE_DROP) / (10000 * 3600);
        uint256 timeToReserve = totalDrop / dropPerSecond;

        // Fast forward to exactly when price reaches reserve
        vm.warp(block.timestamp + timeToReserve);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);
        uint256 reservePrice = auction.reservePrice;

        // Price should be at or very close to reserve price
        assertApproxEqAbs(currentPrice, reservePrice, 0.01 ether);
    }

    function test_GetCurrentPrice_BeyondReserveTime() public {
        bytes32 auctionId = createBasicDutchAuction(1);

        // Get auction details
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);

        // Calculate time when price reaches reserve manually
        uint256 totalDrop = auction.startPrice - auction.reservePrice;
        uint256 dropPerSecond = (auction.startPrice * DEFAULT_PRICE_DROP) / (10000 * 3600);
        uint256 timeToReserve = totalDrop / dropPerSecond;

        // Fast forward beyond reserve time
        vm.warp(block.timestamp + timeToReserve + 1 hours);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);
        uint256 reservePrice = auction.reservePrice;

        // Price should not go below reserve
        assertEq(currentPrice, reservePrice);
    }

    function test_GetCurrentPrice_VeryHighPriceDrop() public {
        // NFT is already minted in setup, just need approval
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);

        bytes32 auctionId = auctionFactory.createDutchAuction(
            address(mockERC721),
            3, // Use token ID 3 to avoid conflicts
            1,
            10 ether, // Start price
            1 ether, // Reserve price
            2 hours, // Short duration
            4500 // 45% drop per hour (very high)
        );
        vm.stopPrank();

        // Fast forward 1 hour
        vm.warp(block.timestamp + 1 hours);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);

        // Price should have dropped significantly but not below reserve
        assertTrue(currentPrice >= 1 ether);
        assertTrue(currentPrice < 10 ether);
    }

    function test_GetCurrentPrice_MinimalPriceDrop() public {
        // NFT is already minted in setup, just need approval
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);

        bytes32 auctionId = auctionFactory.createDutchAuction(
            address(mockERC721),
            4, // Use token ID 4 to avoid conflicts
            1,
            10 ether, // Start price
            9 ether, // High reserve price
            24 hours, // Long duration
            100 // 1% drop per hour (minimal)
        );
        vm.stopPrank();

        // Fast forward 1 hour
        vm.warp(block.timestamp + 1 hours);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);

        // Price should have dropped only slightly
        assertApproxEqAbs(currentPrice, 9.9 ether, 0.1 ether);
    }

    // ============================================================================
    // BUY NOW EDGE CASES
    // ============================================================================

    function test_BuyNow_ExactPriceAtReserve() public {
        bytes32 auctionId = createBasicDutchAuction(1);

        // Fast forward to reserve price using Dutch auction contract
        uint256 timeToReserve = auctionFactory.dutchAuction().getTimeToReservePrice(auctionId);
        vm.warp(block.timestamp + timeToReserve);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);

        vm.deal(BIDDER1, currentPrice);
        vm.prank(BIDDER1);
        auctionFactory.buyNow{value: currentPrice}(auctionId);

        // Auction should be settled
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        assertEq(uint8(auction.status), uint8(IAuction.AuctionStatus.SETTLED));
    }

    function test_BuyNow_WithExcessPayment_LargeAmount() public {
        bytes32 auctionId = createBasicDutchAuction(1);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);
        uint256 excessPayment = currentPrice + 100 ether; // Large excess

        vm.deal(BIDDER1, excessPayment);

        vm.prank(BIDDER1);
        auctionFactory.buyNow{value: excessPayment}(auctionId);

        // Check refund was processed correctly - buyer should have the excess back
        uint256 buyerBalanceAfter = BIDDER1.balance;
        assertEq(buyerBalanceAfter, 100 ether); // Should have the excess refunded
    }

    function test_BuyNow_JustAfterAuctionStart() public {
        bytes32 auctionId = createBasicDutchAuction(1);

        // Buy immediately after auction starts
        vm.warp(block.timestamp + 1 seconds);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);

        vm.deal(BIDDER1, currentPrice);
        vm.prank(BIDDER1);
        auctionFactory.buyNow{value: currentPrice}(auctionId);

        // Should succeed
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        assertEq(uint8(auction.status), uint8(IAuction.AuctionStatus.SETTLED));
    }

    function test_BuyNow_JustBeforeAuctionEnd() public {
        bytes32 auctionId = createBasicDutchAuction(1);

        // Fast forward to just before auction ends
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        vm.warp(auction.endTime - 1 seconds);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);

        vm.deal(BIDDER1, currentPrice);
        vm.prank(BIDDER1);
        auctionFactory.buyNow{value: currentPrice}(auctionId);

        // Should succeed
        auction = auctionFactory.getAuction(auctionId);
        assertEq(uint8(auction.status), uint8(IAuction.AuctionStatus.SETTLED));
    }

    // ============================================================================
    // AUCTION CREATION EDGE CASES
    // ============================================================================

    function test_CreateDutchAuction_MinimumPriceDrop() public {
        // NFT is already minted in setup, just need approval
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);

        bytes32 auctionId = auctionFactory.createDutchAuction(
            address(mockERC721),
            5, // Use token ID 5 to avoid conflicts
            1,
            10 ether,
            9 ether,
            24 hours,
            100 // 1% per hour (minimum)
        );
        vm.stopPrank();

        assertTrue(auctionId != bytes32(0));
    }

    function test_CreateDutchAuction_MaximumPriceDrop() public {
        // NFT is already minted in setup, just need approval
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);

        bytes32 auctionId = auctionFactory.createDutchAuction(
            address(mockERC721),
            6, // Use token ID 6 to avoid conflicts
            1,
            10 ether,
            1 ether,
            1 hours,
            5000 // 50% per hour (maximum)
        );
        vm.stopPrank();

        assertTrue(auctionId != bytes32(0));
    }

    function test_CreateDutchAuction_RevertPriceDropTooLow() public {
        vm.prank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);

        vm.prank(SELLER);
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        auctionFactory.createDutchAuction(
            address(mockERC721),
            1,
            1,
            10 ether,
            9 ether,
            24 hours,
            99 // Under 1%
        );
    }

    function test_CreateDutchAuction_RevertPriceDropTooHigh() public {
        vm.prank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);

        vm.prank(SELLER);
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        auctionFactory.createDutchAuction(
            address(mockERC721),
            1,
            1,
            10 ether,
            1 ether,
            1 hours,
            5001 // Over 50%
        );
    }

    // ============================================================================
    // SETTLEMENT EDGE CASES
    // ============================================================================

    function test_SettleAuction_ExpiredWithoutBuyer() public {
        bytes32 auctionId = createBasicDutchAuction(1);

        // Fast forward past auction end
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        vm.warp(auction.endTime + 1 seconds);

        // Settle the expired auction through factory
        auctionFactory.settleAuction(auctionId);

        // Should be settled without winner (status 2 = ENDED for Dutch auctions)
        auction = auctionFactory.getAuction(auctionId);
        assertEq(uint8(auction.status), 2); // ENDED
        assertEq(auction.highestBidder, address(0));
    }

    function test_SettleAuction_RevertStillActive() public {
        bytes32 auctionId = createBasicDutchAuction(1);

        // Try to settle while still active through factory
        vm.expectRevert(Auction__AuctionStillActive.selector);
        auctionFactory.settleAuction(auctionId);
    }

    // ============================================================================
    // ERROR CONDITION TESTS
    // ============================================================================

    function test_BuyNow_RevertAfterExpiry() public {
        bytes32 auctionId = createBasicDutchAuction(1);

        // Fast forward past auction end
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        vm.warp(auction.endTime + 1 seconds);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);

        vm.deal(BIDDER1, currentPrice);
        vm.prank(BIDDER1);
        vm.expectRevert(Auction__AuctionNotActive.selector);
        auctionFactory.buyNow{value: currentPrice}(auctionId);
    }

    function test_BuyNow_RevertInsufficientPayment_EdgeCase() public {
        bytes32 auctionId = createBasicDutchAuction(1);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);
        uint256 insufficientPayment = currentPrice - 1 wei; // Just 1 wei short

        vm.deal(BIDDER1, insufficientPayment);
        vm.prank(BIDDER1);
        vm.expectRevert(Auction__InsufficientPayment.selector);
        auctionFactory.buyNow{value: insufficientPayment}(auctionId);
    }

    function test_GetTimeToReservePrice_InstantReserve() public {
        // NFT is already minted in setup, just need approval
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);

        bytes32 auctionId = auctionFactory.createDutchAuction(
            address(mockERC721),
            7, // Use token ID 7 to avoid conflicts
            1,
            5 ether, // Start price
            5 ether, // Same reserve price
            24 hours,
            1000 // 10% per hour
        );
        vm.stopPrank();

        uint256 timeToReserve = auctionFactory.dutchAuction().getTimeToReservePrice(auctionId);
        assertEq(timeToReserve, 0); // Should be instant
    }
}
