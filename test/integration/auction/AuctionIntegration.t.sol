// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {AuctionFactory} from "src/core/auction/AuctionFactory.sol";
import {EnglishAuction} from "src/core/auction/EnglishAuction.sol";
import {DutchAuction} from "src/core/auction/DutchAuction.sol";
import {IAuction} from "src/interfaces/IAuction.sol";
import {AuctionTestHelpers} from "../../utils/auction/AuctionTestHelpers.sol";

/**
 * @title AuctionIntegrationTest
 * @notice Integration tests for the complete auction system
 * @dev Tests end-to-end workflows and cross-contract interactions
 */
contract AuctionIntegrationTest is AuctionTestHelpers {
    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        setUpAuctionTests();
    }

    // Allow contract to receive ETH for royalty payments
    receive() external payable override {}
    fallback() external payable {}

    // ============================================================================
    // END-TO-END ENGLISH AUCTION TESTS
    // ============================================================================

    function test_EnglishAuction_CompleteWorkflow_Success() public {
        uint256 tokenId = 1;

        // 1. Create auction through factory
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createEnglishAuction(
            address(mockERC721), tokenId, 1, DEFAULT_START_PRICE, DEFAULT_RESERVE_PRICE, DEFAULT_DURATION
        );
        vm.stopPrank();

        // 2. Multiple bidders place bids
        uint256 bid1 = DEFAULT_START_PRICE;
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: bid1}(auctionId);

        uint256 bid2 = calculateMinNextBid(bid1);
        vm.prank(BIDDER2);
        auctionFactory.placeBid{value: bid2}(auctionId);

        uint256 bid3 = calculateMinNextBid(bid2);
        vm.prank(BIDDER3);
        auctionFactory.placeBid{value: bid3}(auctionId);

        // 3. Verify auction state
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        assertEq(auction.highestBidder, BIDDER3);
        assertEq(auction.highestBid, bid3);
        assertEq(auction.bidCount, 3);

        // 4. Outbid bidders withdraw refunds
        uint256 bidder1BalanceBefore = BIDDER1.balance;
        vm.prank(BIDDER1);
        auctionFactory.withdrawBid(auctionId);
        assertEq(BIDDER1.balance, bidder1BalanceBefore + bid1);

        uint256 bidder2BalanceBefore = BIDDER2.balance;
        vm.prank(BIDDER2);
        auctionFactory.withdrawBid(auctionId);
        assertEq(BIDDER2.balance, bidder2BalanceBefore + bid2);

        // 5. Fast forward to auction end
        fastForwardToAuctionEnd(auctionId);

        // 6. Settle auction
        uint256 sellerBalanceBefore = SELLER.balance;
        uint256 marketplaceBalanceBefore = MARKETPLACE_WALLET.balance;

        auctionFactory.settleAuction(auctionId);

        // 7. Verify final state
        assertNFTOwnership(address(mockERC721), tokenId, BIDDER3);

        auction = auctionFactory.getAuction(auctionId);
        assertEq(uint256(auction.status), uint256(IAuction.AuctionStatus.SETTLED));

        // Verify payments
        uint256 marketplaceFee = (bid3 * 200) / 10000; // 2% fee
        assertGt(SELLER.balance, sellerBalanceBefore);
        assertEq(MARKETPLACE_WALLET.balance, marketplaceBalanceBefore + marketplaceFee);
    }

    function test_EnglishAuction_WithRoyalties_Success() public {
        uint256 tokenId = 1;
        address royaltyReceiver = address(0x888);

        // Set royalty for the token (10%)
        mockERC721.setTokenRoyalty(tokenId, royaltyReceiver, 1000);

        // Create and run auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createEnglishAuction(
            address(mockERC721), tokenId, 1, DEFAULT_START_PRICE, DEFAULT_RESERVE_PRICE, DEFAULT_DURATION
        );
        vm.stopPrank();

        // Place winning bid
        uint256 winningBid = DEFAULT_START_PRICE;
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: winningBid}(auctionId);

        // Fast forward and settle
        fastForwardToAuctionEnd(auctionId);

        uint256 royaltyReceiverBalanceBefore = royaltyReceiver.balance;
        auctionFactory.settleAuction(auctionId);

        // Verify royalty payment
        uint256 expectedRoyalty = (winningBid * 1000) / 10000; // 10%
        assertEq(royaltyReceiver.balance, royaltyReceiverBalanceBefore + expectedRoyalty);
    }

    function test_EnglishAuction_ReserveNotMet_RefundsAll() public {
        uint256 tokenId = 1;
        uint256 highReserve = 2 ether;

        // Create auction with high reserve
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createEnglishAuction(
            address(mockERC721), tokenId, 1, DEFAULT_START_PRICE, highReserve, DEFAULT_DURATION
        );
        vm.stopPrank();

        // Place bid below reserve
        uint256 bid = DEFAULT_START_PRICE;
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: bid}(auctionId);

        // Fast forward and settle
        fastForwardToAuctionEnd(auctionId);
        auctionFactory.settleAuction(auctionId);

        // Verify auction ended without sale
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        assertEq(uint256(auction.status), uint256(IAuction.AuctionStatus.ENDED));

        // Verify NFT still with seller
        assertNFTOwnership(address(mockERC721), tokenId, SELLER);

        // Verify bidder can withdraw refund
        uint256 bidderBalanceBefore = BIDDER1.balance;
        vm.prank(BIDDER1);
        auctionFactory.withdrawBid(auctionId);
        assertEq(BIDDER1.balance, bidderBalanceBefore + bid);
    }

    // ============================================================================
    // END-TO-END DUTCH AUCTION TESTS
    // ============================================================================

    function test_DutchAuction_CompleteWorkflow_Success() public {
        uint256 tokenId = 1;

        // 1. Create Dutch auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createDutchAuction(
            address(mockERC721),
            tokenId,
            1,
            DEFAULT_START_PRICE,
            DEFAULT_RESERVE_PRICE,
            DEFAULT_DURATION,
            DEFAULT_PRICE_DROP
        );
        vm.stopPrank();

        // 2. Wait for price to drop
        fastForward(3 hours);

        // 3. Check current price
        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);
        assertLt(currentPrice, DEFAULT_START_PRICE);

        // 4. Purchase at current price
        uint256 sellerBalanceBefore = SELLER.balance;
        uint256 marketplaceBalanceBefore = MARKETPLACE_WALLET.balance;

        vm.prank(BIDDER1);
        auctionFactory.buyNow{value: currentPrice}(auctionId);

        // 5. Verify final state
        assertNFTOwnership(address(mockERC721), tokenId, BIDDER1);

        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        assertEq(uint256(auction.status), uint256(IAuction.AuctionStatus.SETTLED));
        assertEq(auction.highestBidder, BIDDER1);
        assertEq(auction.highestBid, currentPrice);

        // Verify payments
        uint256 marketplaceFee = (currentPrice * 200) / 10000; // 2% fee
        assertGt(SELLER.balance, sellerBalanceBefore);
        assertEq(MARKETPLACE_WALLET.balance, marketplaceBalanceBefore + marketplaceFee);
    }

    function test_DutchAuction_PriceReachesReserve_Success() public {
        uint256 tokenId = 1;

        // Create auction with aggressive price drop
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createDutchAuction(
            address(mockERC721),
            tokenId,
            1,
            DEFAULT_START_PRICE,
            DEFAULT_RESERVE_PRICE,
            DEFAULT_DURATION,
            5000 // 50% per hour
        );
        vm.stopPrank();

        // Fast forward until price reaches reserve
        fastForward(5 hours);

        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);
        assertEq(currentPrice, DEFAULT_RESERVE_PRICE);

        // Purchase at reserve price
        vm.prank(BIDDER1);
        auctionFactory.buyNow{value: currentPrice}(auctionId);

        // Verify successful purchase
        assertNFTOwnership(address(mockERC721), tokenId, BIDDER1);
    }

    function test_DutchAuction_ExpiresUnsold_Success() public {
        uint256 tokenId = 1;

        // Create Dutch auction
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createDutchAuction(
            address(mockERC721),
            tokenId,
            1,
            DEFAULT_START_PRICE,
            DEFAULT_RESERVE_PRICE,
            DEFAULT_DURATION,
            DEFAULT_PRICE_DROP
        );
        vm.stopPrank();

        // Fast forward past auction end without purchase
        fastForwardToAuctionEnd(auctionId);

        // Settle expired auction
        auctionFactory.settleAuction(auctionId);

        // Verify auction ended without sale
        IAuction.Auction memory auction = auctionFactory.getAuction(auctionId);
        assertEq(uint256(auction.status), uint256(IAuction.AuctionStatus.ENDED));

        // Verify NFT still with seller
        assertNFTOwnership(address(mockERC721), tokenId, SELLER);
    }

    // ============================================================================
    // MIXED AUCTION TYPE TESTS
    // ============================================================================

    function test_MultipleAuctionTypes_Concurrent_Success() public {
        // Create both types of auctions concurrently
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);

        bytes32 englishAuctionId = auctionFactory.createEnglishAuction(
            address(mockERC721), 1, 1, DEFAULT_START_PRICE, DEFAULT_RESERVE_PRICE, DEFAULT_DURATION
        );

        bytes32 dutchAuctionId = auctionFactory.createDutchAuction(
            address(mockERC721), 2, 1, DEFAULT_START_PRICE, DEFAULT_RESERVE_PRICE, DEFAULT_DURATION, DEFAULT_PRICE_DROP
        );
        vm.stopPrank();

        // Interact with both auctions
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: DEFAULT_START_PRICE}(englishAuctionId);

        fastForward(2 hours);
        uint256 dutchPrice = auctionFactory.getCurrentPrice(dutchAuctionId);

        vm.prank(BIDDER2);
        auctionFactory.buyNow{value: dutchPrice}(dutchAuctionId);

        // Verify both auctions work independently
        IAuction.Auction memory englishAuction = auctionFactory.getAuction(englishAuctionId);
        IAuction.Auction memory dutchAuction = auctionFactory.getAuction(dutchAuctionId);

        assertEq(englishAuction.highestBidder, BIDDER1);
        assertEq(uint256(englishAuction.status), uint256(IAuction.AuctionStatus.ACTIVE));

        assertEq(dutchAuction.highestBidder, BIDDER2);
        assertEq(uint256(dutchAuction.status), uint256(IAuction.AuctionStatus.SETTLED));

        // Verify NFT ownership
        assertNFTOwnership(address(mockERC721), 1, SELLER); // Still in English auction
        assertNFTOwnership(address(mockERC721), 2, BIDDER2); // Sold in Dutch auction
    }

    // ============================================================================
    // ERC1155 INTEGRATION TESTS
    // ============================================================================

    function test_ERC1155_EnglishAuction_Success() public {
        uint256 tokenId = 1;
        uint256 amount = 10;

        // Create ERC1155 English auction
        vm.startPrank(SELLER);
        mockERC1155.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createEnglishAuction(
            address(mockERC1155), tokenId, amount, DEFAULT_START_PRICE, DEFAULT_RESERVE_PRICE, DEFAULT_DURATION
        );
        vm.stopPrank();

        // Place winning bid and settle
        vm.prank(BIDDER1);
        auctionFactory.placeBid{value: DEFAULT_START_PRICE}(auctionId);

        fastForwardToAuctionEnd(auctionId);
        auctionFactory.settleAuction(auctionId);

        // Verify ERC1155 transfer
        assertEq(mockERC1155.balanceOf(BIDDER1, tokenId), amount);
        assertEq(mockERC1155.balanceOf(SELLER, tokenId), 100 - amount); // Original 100 - transferred amount
    }

    function test_ERC1155_DutchAuction_Success() public {
        uint256 tokenId = 1;
        uint256 amount = 5;

        // Create ERC1155 Dutch auction
        vm.startPrank(SELLER);
        mockERC1155.setApprovalForAll(address(auctionFactory), true);
        bytes32 auctionId = auctionFactory.createDutchAuction(
            address(mockERC1155),
            tokenId,
            amount,
            DEFAULT_START_PRICE,
            DEFAULT_RESERVE_PRICE,
            DEFAULT_DURATION,
            DEFAULT_PRICE_DROP
        );
        vm.stopPrank();

        // Purchase immediately
        uint256 currentPrice = auctionFactory.getCurrentPrice(auctionId);

        vm.prank(BIDDER1);
        auctionFactory.buyNow{value: currentPrice}(auctionId);

        // Verify ERC1155 transfer
        assertEq(mockERC1155.balanceOf(BIDDER1, tokenId), amount);
        assertEq(mockERC1155.balanceOf(SELLER, tokenId), 100 - amount);
    }

    // ============================================================================
    // STRESS TESTS
    // ============================================================================

    function test_HighVolumeAuctions_Success() public {
        uint256 numAuctions = 10;
        bytes32[] memory auctionIds = new bytes32[](numAuctions);

        // Create multiple auctions
        vm.startPrank(SELLER);
        mockERC721.setApprovalForAll(address(auctionFactory), true);

        for (uint256 i = 0; i < numAuctions; i++) {
            if (i % 2 == 0) {
                auctionIds[i] = auctionFactory.createEnglishAuction(
                    address(mockERC721), i + 1, 1, DEFAULT_START_PRICE, DEFAULT_RESERVE_PRICE, DEFAULT_DURATION
                );
            } else {
                auctionIds[i] = auctionFactory.createDutchAuction(
                    address(mockERC721),
                    i + 1,
                    1,
                    DEFAULT_START_PRICE,
                    DEFAULT_RESERVE_PRICE,
                    DEFAULT_DURATION,
                    DEFAULT_PRICE_DROP
                );
            }
        }
        vm.stopPrank();

        // Verify all auctions created
        bytes32[] memory allAuctions = auctionFactory.getAllAuctions();
        assertEq(allAuctions.length, numAuctions);

        // Verify user auctions
        bytes32[] memory userAuctions = auctionFactory.getUserAuctions(SELLER);
        assertEq(userAuctions.length, numAuctions);

        // Interact with some auctions
        for (uint256 i = 0; i < numAuctions; i += 3) {
            if (i % 2 == 0) {
                // English auction - place bid
                vm.prank(BIDDER1);
                auctionFactory.placeBid{value: DEFAULT_START_PRICE}(auctionIds[i]);
            } else {
                // Dutch auction - buy now
                uint256 currentPrice = auctionFactory.getCurrentPrice(auctionIds[i]);
                vm.prank(BIDDER1);
                auctionFactory.buyNow{value: currentPrice}(auctionIds[i]);
            }
        }

        // Verify system still functions correctly
        assertTrue(auctionFactory.isAuctionActive(auctionIds[0])); // English with bid
        assertFalse(auctionFactory.isAuctionActive(auctionIds[3])); // Dutch sold
    }
}
