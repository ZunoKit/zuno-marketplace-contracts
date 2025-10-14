// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {DutchAuction} from "src/core/auction/DutchAuction.sol";
import {IAuction} from "src/interfaces/IAuction.sol";
import {AuctionType, AuctionStatus} from "src/types/AuctionTypes.sol";
import {AuctionTestHelpers} from "test/utils/auction/AuctionTestHelpers.sol";
import "src/errors/AuctionErrors.sol";

/**
 * @title DutchAuctionTest
 * @notice Unit tests for DutchAuction contract
 * @dev Tests all functionality of Dutch auctions including price calculations
 */
contract DutchAuctionTest is AuctionTestHelpers {
    // ============================================================================
    // EVENTS FOR TESTING
    // ============================================================================

    event AuctionCreated(
        bytes32 indexed auctionId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 startTime,
        uint256 endTime,
        uint8 auctionType
    );

    event DutchAuctionPurchase(
        bytes32 indexed auctionId, address indexed buyer, uint256 purchasePrice, uint256 currentPrice
    );

    event AuctionSettled(bytes32 indexed auctionId, address indexed winner, uint256 finalPrice, address indexed seller);

    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        setUpAuctionTests();
    }

    /**
     * @notice Helper to create a basic Dutch auction using standalone contract
     * @param tokenId Token ID to auction
     * @return auctionId The created auction ID
     */
    function createBasicStandaloneDutchAuction(uint256 tokenId) internal returns (bytes32 auctionId) {
        vm.startPrank(SELLER);

        // Approve standalone contract
        mockERC721.setApprovalForAll(address(dutchAuction), true);

        auctionId = dutchAuction.createDutchAuction(
            address(mockERC721),
            tokenId,
            1,
            DEFAULT_START_PRICE,
            DEFAULT_RESERVE_PRICE,
            DEFAULT_DURATION,
            DEFAULT_PRICE_DROP,
            SELLER
        );

        vm.stopPrank();
        return auctionId;
    }

    // ============================================================================
    // AUCTION CREATION TESTS
    // ============================================================================

    function test_CreateDutchAuction_Success() public {
        uint256 tokenId = 1;

        bytes32 auctionId = createBasicStandaloneDutchAuction(tokenId);

        // Verify auction details
        IAuction.Auction memory auction = dutchAuction.getAuction(auctionId);
        assertEq(auction.nftContract, address(mockERC721));
        assertEq(auction.tokenId, tokenId);
        assertEq(auction.seller, SELLER);
        assertEq(auction.startPrice, DEFAULT_START_PRICE);
        assertEq(auction.reservePrice, DEFAULT_RESERVE_PRICE);
        assertEq(uint256(auction.status), uint256(AuctionStatus.ACTIVE));
        assertEq(uint256(auction.auctionType), uint256(AuctionType.DUTCH));

        // Verify Dutch auction specific parameters
        uint256 priceDropPerHour = dutchAuction.getPriceDropPerHour(auctionId);
        assertEq(priceDropPerHour, DEFAULT_PRICE_DROP);
    }

    function test_CreateDutchAuction_RevertIfInvalidPriceDrop() public {
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(dutchAuction), true);

        // Too low price drop
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        dutchAuction.createDutchAuction(
            address(mockERC721),
            1,
            1,
            DEFAULT_START_PRICE,
            DEFAULT_RESERVE_PRICE,
            DEFAULT_DURATION,
            50, // Too low (< 100)
            SELLER
        );

        // Too high price drop
        vm.expectRevert(Auction__InvalidAuctionParameters.selector);
        dutchAuction.createDutchAuction(
            address(mockERC721),
            1,
            1,
            DEFAULT_START_PRICE,
            DEFAULT_RESERVE_PRICE,
            DEFAULT_DURATION,
            6000, // Too high (> 5000)
            SELLER
        );

        vm.stopPrank();
    }

    // ============================================================================
    // PRICE CALCULATION TESTS
    // ============================================================================

    function test_GetCurrentPrice_AtStart() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        uint256 currentPrice = dutchAuction.getCurrentPrice(auctionId);
        assertEq(currentPrice, DEFAULT_START_PRICE);
    }

    function test_GetCurrentPrice_AfterOneHour() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        // Fast forward 1 hour
        fastForward(1 hours);

        uint256 currentPrice = dutchAuction.getCurrentPrice(auctionId);
        uint256 expectedPrice = calculateDutchPrice(DEFAULT_START_PRICE, DEFAULT_PRICE_DROP, 1, DEFAULT_RESERVE_PRICE);

        assertEq(currentPrice, expectedPrice);
    }

    function test_GetCurrentPrice_AfterMultipleHours() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        // Fast forward 5 hours
        fastForward(5 hours);

        uint256 currentPrice = dutchAuction.getCurrentPrice(auctionId);
        uint256 expectedPrice = calculateDutchPrice(DEFAULT_START_PRICE, DEFAULT_PRICE_DROP, 5, DEFAULT_RESERVE_PRICE);

        assertEq(currentPrice, expectedPrice);
    }

    function test_GetCurrentPrice_ReachesReserve() public {
        // Create auction with high price drop to quickly reach reserve
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(dutchAuction), true);

        bytes32 auctionId = dutchAuction.createDutchAuction(
            address(mockERC721),
            1,
            1,
            DEFAULT_START_PRICE,
            DEFAULT_RESERVE_PRICE,
            DEFAULT_DURATION,
            5000, // 50% per hour
            SELLER
        );
        vm.stopPrank();

        // Fast forward enough to reach reserve
        fastForward(3 hours);

        uint256 currentPrice = dutchAuction.getCurrentPrice(auctionId);
        assertEq(currentPrice, DEFAULT_RESERVE_PRICE);
    }

    function test_GetPriceAtTime_SpecificTimestamp() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        uint256 futureTime = block.timestamp + 2 hours;
        uint256 priceAtTime = dutchAuction.getPriceAtTime(auctionId, futureTime);

        uint256 expectedPrice = calculateDutchPrice(DEFAULT_START_PRICE, DEFAULT_PRICE_DROP, 2, DEFAULT_RESERVE_PRICE);

        assertEq(priceAtTime, expectedPrice);
    }

    function test_GetTimeToReservePrice() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        uint256 timeToReserve = dutchAuction.getTimeToReservePrice(auctionId);

        // Should be > 0 since we have a reserve price
        assertGt(timeToReserve, 0);
    }

    // ============================================================================
    // PURCHASE TESTS
    // ============================================================================

    function test_BuyNow_AtStartPrice_Success() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);
        uint256 purchasePrice = DEFAULT_START_PRICE;

        vm.expectEmit(true, true, false, true);
        emit DutchAuctionPurchase(auctionId, BIDDER1, purchasePrice, purchasePrice);

        vm.expectEmit(true, true, true, true);
        emit AuctionSettled(auctionId, BIDDER1, purchasePrice, SELLER);

        vm.prank(BIDDER1);
        dutchAuction.buyNow{value: purchasePrice}(auctionId);

        // Verify NFT transferred
        assertNFTOwnership(address(mockERC721), 1, BIDDER1);

        // Verify auction settled
        IAuction.Auction memory auction = dutchAuction.getAuction(auctionId);
        assertEq(uint256(auction.status), uint256(AuctionStatus.SETTLED));
        assertEq(auction.highestBidder, BIDDER1);
        assertEq(auction.highestBid, purchasePrice);
    }

    function test_BuyNow_AfterPriceDrop_Success() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        // Fast forward 2 hours for price drop
        fastForward(2 hours);

        uint256 currentPrice = dutchAuction.getCurrentPrice(auctionId);
        assertLt(currentPrice, DEFAULT_START_PRICE);

        // Record balances before purchase
        uint256 sellerBalanceBefore = SELLER.balance;
        uint256 marketplaceBalanceBefore = MARKETPLACE_WALLET.balance;

        vm.prank(BIDDER1);
        dutchAuction.buyNow{value: currentPrice}(auctionId);

        // Verify NFT transferred
        assertNFTOwnership(address(mockERC721), 1, BIDDER1);

        // Verify payments distributed
        uint256 marketplaceFee = (currentPrice * 200) / 10000; // 2% fee
        assertGt(SELLER.balance, sellerBalanceBefore);
        assertEq(MARKETPLACE_WALLET.balance, marketplaceBalanceBefore + marketplaceFee);
    }

    function test_BuyNow_WithExcessPayment_RefundsExcess() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        uint256 currentPrice = dutchAuction.getCurrentPrice(auctionId);
        uint256 excessPayment = currentPrice + 0.5 ether;

        uint256 buyerBalanceBefore = BIDDER1.balance;

        vm.prank(BIDDER1);
        dutchAuction.buyNow{value: excessPayment}(auctionId);

        // Verify excess was refunded
        uint256 expectedBalance = buyerBalanceBefore - currentPrice;
        assertEq(BIDDER1.balance, expectedBalance);
    }

    function test_BuyNow_RevertIfInsufficientPayment() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        uint256 currentPrice = dutchAuction.getCurrentPrice(auctionId);

        vm.prank(BIDDER1);
        vm.expectRevert(Auction__InsufficientPayment.selector);
        dutchAuction.buyNow{value: currentPrice - 1}(auctionId);
    }

    function test_BuyNow_RevertIfSellerTries() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        uint256 currentPrice = dutchAuction.getCurrentPrice(auctionId);

        vm.prank(SELLER);
        vm.expectRevert(Auction__SellerCannotBid.selector);
        dutchAuction.buyNow{value: currentPrice}(auctionId);
    }

    function test_BuyNow_RevertIfAuctionEnded() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        // Fast forward past auction end
        IAuction.Auction memory auction = dutchAuction.getAuction(auctionId);
        vm.warp(auction.endTime + 1);

        vm.prank(BIDDER1);
        vm.expectRevert(Auction__AuctionNotActive.selector);
        dutchAuction.buyNow{value: DEFAULT_START_PRICE}(auctionId);
    }

    // ============================================================================
    // SETTLEMENT TESTS
    // ============================================================================

    function test_SettleAuction_Unsold_Success() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        // Fast forward to auction end without purchase
        IAuction.Auction memory auction = dutchAuction.getAuction(auctionId);
        vm.warp(auction.endTime + 1);

        dutchAuction.settleAuction(auctionId);

        // Verify auction ended without winner
        IAuction.Auction memory settledAuction = dutchAuction.getAuction(auctionId);
        assertEq(uint256(settledAuction.status), uint256(AuctionStatus.ENDED));

        // Verify NFT still with seller
        assertNFTOwnership(address(mockERC721), 1, SELLER);
    }

    function test_SettleAuction_RevertIfStillActive() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        vm.expectRevert(Auction__AuctionStillActive.selector);
        dutchAuction.settleAuction(auctionId);
    }

    // ============================================================================
    // CANCELLATION TESTS
    // ============================================================================

    function test_CancelAuction_Success() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        vm.prank(SELLER);
        dutchAuction.cancelAuction(auctionId);

        IAuction.Auction memory auction = dutchAuction.getAuction(auctionId);
        assertEq(uint256(auction.status), uint256(AuctionStatus.CANCELLED));
    }

    function test_CancelAuction_RevertIfNotSeller() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        vm.prank(BIDDER1);
        vm.expectRevert(Auction__NotAuctionSeller.selector);
        dutchAuction.cancelAuction(auctionId);
    }

    // ============================================================================
    // UNSUPPORTED FUNCTION TESTS
    // ============================================================================

    function test_PlaceBid_RevertUnsupported() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        vm.prank(BIDDER1);
        vm.expectRevert(Auction__UnsupportedAuctionType.selector);
        dutchAuction.placeBid{value: DEFAULT_START_PRICE}(auctionId);
    }

    function test_WithdrawBid_RevertUnsupported() public {
        bytes32 auctionId = createBasicStandaloneDutchAuction(1);

        vm.prank(BIDDER1);
        vm.expectRevert(Auction__UnsupportedAuctionType.selector);
        dutchAuction.withdrawBid(auctionId);
    }

    // ============================================================================
    // ERC1155 TESTS
    // ============================================================================

    function test_CreateDutchAuction_ERC1155_Success() public {
        uint256 tokenId = 1;
        uint256 amount = 5;

        vm.startPrank(SELLER);
        mockERC1155.setApprovalForAll(address(dutchAuction), true);

        bytes32 auctionId = dutchAuction.createDutchAuction(
            address(mockERC1155),
            tokenId,
            amount,
            DEFAULT_START_PRICE,
            DEFAULT_RESERVE_PRICE,
            DEFAULT_DURATION,
            DEFAULT_PRICE_DROP,
            SELLER
        );
        vm.stopPrank();

        // Verify auction details
        IAuction.Auction memory auction = dutchAuction.getAuction(auctionId);
        assertEq(auction.nftContract, address(mockERC1155));
        assertEq(auction.tokenId, tokenId);
        assertEq(auction.amount, amount);
    }

    function test_BuyNow_ERC1155_Success() public {
        uint256 tokenId = 1;
        uint256 amount = 5;

        vm.startPrank(SELLER);
        mockERC1155.setApprovalForAll(address(dutchAuction), true);

        bytes32 auctionId = dutchAuction.createDutchAuction(
            address(mockERC1155),
            tokenId,
            amount,
            DEFAULT_START_PRICE,
            DEFAULT_RESERVE_PRICE,
            DEFAULT_DURATION,
            DEFAULT_PRICE_DROP,
            SELLER
        );
        vm.stopPrank();

        uint256 currentPrice = dutchAuction.getCurrentPrice(auctionId);

        uint256 buyerBalanceBefore = mockERC1155.balanceOf(BIDDER1, tokenId);

        vm.prank(BIDDER1);
        dutchAuction.buyNow{value: currentPrice}(auctionId);

        // Verify ERC1155 tokens transferred
        uint256 buyerBalanceAfter = mockERC1155.balanceOf(BIDDER1, tokenId);
        assertEq(buyerBalanceAfter, buyerBalanceBefore + amount);
    }
}
