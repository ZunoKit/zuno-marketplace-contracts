// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {AuctionType} from "src/types/AuctionTypes.sol";
import "src/core/validation/MarketplaceValidator.sol";
import "src/core/exchange/ERC721NFTExchange.sol";
import "src/core/exchange/ERC1155NFTExchange.sol";
import "src/core/auction/EnglishAuction.sol";
import "src/interfaces/IAuction.sol";
import "test/mocks/MockERC721.sol";
import "test/mocks/MockERC1155.sol";
import "src/errors/NFTExchangeErrors.sol";

/**
 * @title BasicWorkflows
 * @dev Integration tests for basic marketplace workflows
 */
contract BasicWorkflowsTest is Test {
    MarketplaceValidator public validator;
    ERC721NFTExchange public erc721Exchange;
    ERC1155NFTExchange public erc1155Exchange;
    EnglishAuction public englishAuction;

    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public marketplaceWallet = address(0x4);

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant PRICE = 1 ether;
    uint256 public constant TAKER_FEE_BPS = 200; // 2%
    uint256 public constant BPS_DENOMINATOR = 10000;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy core contracts
        validator = new MarketplaceValidator();

        // Deploy mock NFT contracts
        mockERC721 = new MockERC721("Test721", "T721");
        mockERC1155 = new MockERC1155("Test1155", "T1155");

        // Deploy exchange contracts
        erc721Exchange = new ERC721NFTExchange();
        erc721Exchange.initialize(marketplaceWallet, owner);
        erc1155Exchange = new ERC1155NFTExchange();
        erc1155Exchange.initialize(marketplaceWallet, owner);

        // Deploy auction contracts
        englishAuction = new EnglishAuction(marketplaceWallet);

        // Setup test NFTs
        mockERC721.mint(user1, TOKEN_ID);
        mockERC1155.mint(user1, TOKEN_ID, 10);

        vm.stopPrank();

        // Setup approvals - use setApprovalForAll to avoid conflicts
        vm.startPrank(user1);
        mockERC721.setApprovalForAll(address(erc721Exchange), true);
        mockERC1155.setApprovalForAll(address(erc1155Exchange), true);
        mockERC721.setApprovalForAll(address(englishAuction), true);
        vm.stopPrank();
    }

    function test_BasicERC721Workflow() public {
        // 1. Get listing ID before creating the listing
        bytes32 listingId = erc721Exchange.getGeneratedListingId(address(mockERC721), TOKEN_ID, user1);

        // 2. User1 lists NFT
        vm.startPrank(user1);
        erc721Exchange.listNFT(address(mockERC721), TOKEN_ID, PRICE, 86400);
        vm.stopPrank();

        // 3. User2 buys NFT
        vm.startPrank(user2);
        uint256 takerFee = (PRICE * TAKER_FEE_BPS) / BPS_DENOMINATOR;
        uint256 royaltyFee = (PRICE * 500) / BPS_DENOMINATOR; // 5% royalty from MockERC721
        uint256 totalPrice = PRICE + takerFee + royaltyFee;
        vm.deal(user2, totalPrice);
        erc721Exchange.buyNFT{value: totalPrice}(listingId);
        vm.stopPrank();

        // 4. Verify ownership transfer
        assertEq(mockERC721.ownerOf(TOKEN_ID), user2);
    }

    function test_BasicERC1155Workflow() public {
        // 1. Get listing ID before creating the listing
        bytes32 listingId = erc1155Exchange.getGeneratedListingId(address(mockERC1155), TOKEN_ID, user1);

        // 2. User1 lists NFT
        vm.startPrank(user1);
        erc1155Exchange.listNFT(address(mockERC1155), TOKEN_ID, 5, PRICE, 86400);
        vm.stopPrank();

        // 3. User2 buys NFT
        vm.startPrank(user2);
        uint256 takerFee = (PRICE * TAKER_FEE_BPS) / BPS_DENOMINATOR;
        uint256 royaltyFee = (PRICE * 500) / BPS_DENOMINATOR; // 5% royalty from MockERC1155
        uint256 totalPrice = PRICE + takerFee + royaltyFee;
        vm.deal(user2, totalPrice);
        erc1155Exchange.buyNFT{value: totalPrice}(listingId);
        vm.stopPrank();

        // 4. Verify balance transfer
        assertEq(mockERC1155.balanceOf(user2, TOKEN_ID), 5);
        assertEq(mockERC1155.balanceOf(user1, TOKEN_ID), 5); // remaining
    }

    function test_BasicAuctionWorkflow() public {
        // 1. Create auction
        vm.startPrank(user1);
        bytes32 auctionId = englishAuction.createAuction(
            address(mockERC721),
            TOKEN_ID,
            1,
            PRICE,
            PRICE / 2, // Lower reserve price so bid meets it
            3600,
            AuctionType.ENGLISH,
            user1
        );
        vm.stopPrank();

        // 2. Place bid
        vm.startPrank(user2);
        vm.deal(user2, 5 ether);
        englishAuction.placeBid{value: PRICE}(auctionId);
        vm.stopPrank();

        // 3. Fast forward and settle
        vm.warp(block.timestamp + 3601);

        vm.startPrank(user2);
        englishAuction.settleAuction(auctionId);
        vm.stopPrank();

        // 4. Verify ownership transfer
        assertEq(mockERC721.ownerOf(TOKEN_ID), user2);
    }

    function test_ListingCancellation() public {
        // 1. Get listing ID before creating the listing
        bytes32 listingId = erc721Exchange.getGeneratedListingId(address(mockERC721), TOKEN_ID, user1);

        // 2. Create listing
        vm.startPrank(user1);
        erc721Exchange.listNFT(address(mockERC721), TOKEN_ID, PRICE, 86400);
        vm.stopPrank();

        // 3. Cancel listing
        vm.startPrank(user1);
        erc721Exchange.cancelListing(listingId);
        vm.stopPrank();

        // 4. Verify NFT still owned by user1
        assertEq(mockERC721.ownerOf(TOKEN_ID), user1);
    }

    function test_BatchOperations() public {
        // Setup additional NFTs
        vm.startPrank(owner);
        mockERC721.mint(user1, 2);
        mockERC721.mint(user1, 3);
        vm.stopPrank();

        vm.startPrank(user1);
        // Already approved for all in setUp, no need for individual approvals

        // Batch list NFTs
        address[] memory contracts = new address[](3);
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory prices = new uint256[](3);
        uint256[] memory durations = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            contracts[i] = address(mockERC721);
            tokenIds[i] = i + 1;
            prices[i] = PRICE;
            durations[i] = 86400;
        }

        erc721Exchange.batchListNFT(address(mockERC721), tokenIds, prices, 86400);
        vm.stopPrank();

        // Verify all NFTs still owned by user1 (listed but not sold)
        for (uint256 i = 1; i <= 3; i++) {
            assertEq(mockERC721.ownerOf(i), user1);
        }
    }

    function test_EndToEndMarketplace() public {
        // Complete marketplace workflow test

        // 1. Get listing ID before creating the listing
        bytes32 listingId = erc721Exchange.getGeneratedListingId(address(mockERC721), TOKEN_ID, user1);

        // 2. List NFT
        vm.startPrank(user1);
        erc721Exchange.listNFT(address(mockERC721), TOKEN_ID, PRICE, 86400);
        vm.stopPrank();

        // 3. Cancel listing
        vm.startPrank(user1);
        erc721Exchange.cancelListing(listingId);
        vm.stopPrank();

        // 3. Create auction instead
        vm.startPrank(user1);
        bytes32 auctionId = englishAuction.createAuction(
            address(mockERC721),
            TOKEN_ID,
            1,
            PRICE,
            PRICE / 2, // Lower reserve price so bid meets it
            3600,
            AuctionType.ENGLISH,
            user1
        );
        vm.stopPrank();

        // 4. Place bid and settle
        vm.startPrank(user2);
        vm.deal(user2, 5 ether);
        englishAuction.placeBid{value: PRICE}(auctionId);
        vm.stopPrank();

        vm.warp(block.timestamp + 3601);

        vm.startPrank(user2);
        englishAuction.settleAuction(auctionId);
        vm.stopPrank();

        // 5. Verify final state
        assertEq(mockERC721.ownerOf(TOKEN_ID), user2);
    }

    function test_MultipleUsersWorkflow() public {
        address user3 = address(0x5);
        address user4 = address(0x6);

        // Setup more NFTs
        vm.startPrank(owner);
        mockERC721.mint(user3, 2);
        mockERC721.mint(user4, 3);
        vm.stopPrank();

        // Get listing ID for user1's NFT
        bytes32 listingId = erc721Exchange.getGeneratedListingId(address(mockERC721), TOKEN_ID, user1);

        // Multiple users list NFTs
        vm.startPrank(user1);
        erc721Exchange.listNFT(address(mockERC721), TOKEN_ID, PRICE, 86400);
        vm.stopPrank();

        vm.startPrank(user3);
        mockERC721.setApprovalForAll(address(erc721Exchange), true);
        erc721Exchange.listNFT(address(mockERC721), 2, PRICE * 2, 86400);
        vm.stopPrank();

        vm.startPrank(user4);
        mockERC721.setApprovalForAll(address(erc721Exchange), true);
        erc721Exchange.listNFT(address(mockERC721), 3, PRICE * 3, 86400);
        vm.stopPrank();

        // User2 buys from user1
        vm.startPrank(user2);
        uint256 takerFee = (PRICE * TAKER_FEE_BPS) / BPS_DENOMINATOR;
        uint256 royaltyFee = (PRICE * 500) / BPS_DENOMINATOR; // 5% royalty from MockERC721
        uint256 totalPrice = PRICE + takerFee + royaltyFee;
        vm.deal(user2, 10 ether);
        erc721Exchange.buyNFT{value: totalPrice}(listingId);
        vm.stopPrank();

        // Verify ownership
        assertEq(mockERC721.ownerOf(TOKEN_ID), user2);
        assertEq(mockERC721.ownerOf(2), user3); // still listed
        assertEq(mockERC721.ownerOf(3), user4); // still listed
    }

    function test_ErrorHandling() public {
        // Test various error scenarios

        // Try to buy non-existent listing
        vm.startPrank(user2);
        uint256 takerFee = (PRICE * TAKER_FEE_BPS) / BPS_DENOMINATOR;
        uint256 totalPrice = PRICE + takerFee;
        vm.deal(user2, totalPrice);
        bytes32 fakeListingId = erc721Exchange.getGeneratedListingId(address(mockERC721), TOKEN_ID, user1);
        vm.expectRevert(NFTExchange__NFTNotActive.selector);
        erc721Exchange.buyNFT{value: totalPrice}(fakeListingId);
        vm.stopPrank();

        // Try to list without approval
        vm.startPrank(user1);
        mockERC721.setApprovalForAll(address(erc721Exchange), false); // remove approval for all
        vm.expectRevert(NFTExchange__MarketplaceNotApproved.selector);
        erc721Exchange.listNFT(address(mockERC721), TOKEN_ID, PRICE, 86400);
        vm.stopPrank();

        // Try to list with zero price
        vm.startPrank(user1);
        mockERC721.setApprovalForAll(address(erc721Exchange), true); // re-enable approval
        vm.expectRevert(NFTExchange__PriceMustBeGreaterThanZero.selector);
        erc721Exchange.listNFT(address(mockERC721), TOKEN_ID, 0, 86400);
        vm.stopPrank();
    }
}
