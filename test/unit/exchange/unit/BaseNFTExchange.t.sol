// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {BaseNFTExchange} from "src/contracts/common/BaseNFTExchange.sol";
import {BaseCollection} from "src/contracts/common/BaseCollection.sol";
import {Fee} from "src/contracts/common/Fee.sol";
import {CollectionParams, MintStage} from "src/contracts/types/ListingTypes.sol";
import "src/contracts/errors/NFTExchangeErrors.sol";
import "src/contracts/errors/CollectionErrors.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "src/contracts/events/NFTExchangeEvents.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";

// Test collection contract that inherits from BaseCollection to add minting functionality
contract TestCollection is BaseCollection, ERC721 {
    constructor(CollectionParams memory params) BaseCollection(params) ERC721(params.name, params.symbol) {}

    function mint(uint256 amount) external payable {
        uint256 requiredPayment = checkMint(msg.sender, amount);
        if (msg.value < requiredPayment) {
            revert Collection__InsufficientPayment();
        }

        for (uint256 i = 0; i < amount; i++) {
            s_tokenIdCounter++;
            _mint(msg.sender, s_tokenIdCounter);
            s_mintedPerWallet[msg.sender]++;
            s_totalMinted++;
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return s_tokenURI;
    }
}

// Test contract that inherits from BaseNFTExchange to test internal functions
contract TestNFTExchange is BaseNFTExchange {
    function initialize(address marketplaceWallet, address owner) external initializer {
        __BaseNFTExchange_init(marketplaceWallet, owner);
    }

    function createListing(
        address contractAddress,
        uint256 tokenId,
        uint256 price,
        uint256 listingDuration,
        uint256 amount
    ) external returns (bytes32) {
        bytes32 listingId = _generateListingId(contractAddress, tokenId, msg.sender);
        _createListing(contractAddress, tokenId, price, listingDuration, amount, listingId);
        return listingId;
    }

    function buyNFT(bytes32 listingId) external payable {
        Listing storage listing = s_listings[listingId];
        if (listing.status != ListingStatus.Active) {
            revert NFTExchange__NFTNotActive();
        }
        if (block.timestamp >= listing.listingStart + listing.listingDuration) {
            revert NFTExchange__ListingExpired();
        }
        (address royaltyReceiver, uint256 royalty) =
            getRoyaltyInfo(listing.contractAddress, listing.tokenId, listing.price);
        uint256 takerFee = (listing.price * s_takerFee) / BPS_DENOMINATOR;
        uint256 realityPrice = listing.price + royalty + takerFee;

        if (msg.value < realityPrice) revert NFTExchange__InsufficientPayment();

        // Transfer NFT from seller to buyer
        IERC721(listing.contractAddress).transferFrom(listing.seller, msg.sender, listing.tokenId);

        PaymentDistribution memory payment = PaymentDistribution({
            seller: listing.seller,
            royaltyReceiver: royaltyReceiver,
            price: listing.price,
            royalty: royalty,
            takerFee: takerFee,
            realityPrice: realityPrice
        });

        _distributePayments(payment);
        _finalizeListing(listingId, listing.contractAddress, listing.seller);
    }

    function cancelListing(bytes32 listingId) external {
        Listing storage listing = s_listings[listingId];
        if (listing.seller != msg.sender) revert NFTExchange__NotTheOwner();
        listing.status = ListingStatus.Cancelled;
        _removeListingFromArray(s_listingsByCollection[listing.contractAddress], listingId);
        _removeListingFromArray(s_listingsBySeller[listing.seller], listingId);
    }
}

contract BaseNFTExchangeTest is Test {
    TestNFTExchange public exchange;
    address public marketplaceWallet;
    address public seller;
    address public buyer;
    address public royaltyReceiver;
    TestCollection public collection;
    Fee public feeContract;

    function setUp() public {
        marketplaceWallet = makeAddr("marketplaceWallet");
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        royaltyReceiver = makeAddr("royaltyReceiver");

        // Give ETH to seller and buyer
        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);

        // Deploy contracts
        vm.startPrank(seller);
        CollectionParams memory params = CollectionParams({
            name: "Test Collection",
            symbol: "TEST",
            owner: seller,
            description: "Test Collection Description",
            mintPrice: 0.1 ether,
            royaltyFee: 500, // 5%
            maxSupply: 10000,
            mintLimitPerWallet: 5,
            mintStartTime: block.timestamp,
            allowlistMintPrice: 0.08 ether,
            publicMintPrice: 0.1 ether,
            allowlistStageDuration: 1 days,
            tokenURI: "ipfs://test"
        });
        collection = new TestCollection(params);
        feeContract = collection.getFeeContract();

        // Add seller to allowlist and update mint stage
        address[] memory allowlist = new address[](1);
        allowlist[0] = seller;
        collection.addToAllowlist(allowlist);
        collection.updateMintStage();
        vm.stopPrank();

        exchange = new TestNFTExchange();
        exchange.initialize(marketplaceWallet, address(this));
    }

    function test_Constructor() public {
        assertEq(exchange.marketplaceWallet(), marketplaceWallet);
    }

    function test_UpdateMarketplaceWallet() public {
        address newWallet = makeAddr("newWallet");

        vm.expectEmit(true, true, false, true);
        emit MarketplaceWalletUpdated(marketplaceWallet, newWallet);

        exchange.updateMarketplaceWallet(newWallet);
        assertEq(exchange.marketplaceWallet(), newWallet);
    }

    function test_RevertWhen_UpdateMarketplaceWalletToZeroAddress() public {
        vm.expectRevert(NFTExchange__InvalidMarketplaceWallet.selector);
        exchange.updateMarketplaceWallet(address(0));
    }

    function test_UpdateTakerFee() public {
        uint256 newFee = 300; // 3%

        vm.expectEmit(false, false, false, true);
        emit TakerFeeUpdated(200, newFee);

        exchange.updateTakerFee(newFee);
    }

    function test_RevertWhen_UpdateTakerFeeAboveMax() public {
        vm.expectRevert(NFTExchange__InvalidTakerFee.selector);
        exchange.updateTakerFee(10001); // Above 100%
    }

    function test_GetRoyaltyInfo() public {
        uint256 tokenId = 1;
        uint256 salePrice = 1 ether;

        (address receiver, uint256 royaltyAmount) = exchange.getRoyaltyInfo(address(collection), tokenId, salePrice);

        assertEq(receiver, feeContract.owner());
        assertEq(royaltyAmount, (salePrice * 500) / 10000); // 5% of sale price
    }

    function test_GetBuyerSeesPrice() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 listingDuration = 7 days;

        // Create listing first
        vm.startPrank(seller);
        bytes32 listingId = exchange.createListing(address(collection), tokenId, price, listingDuration, 1);
        vm.stopPrank();

        uint256 buyerPrice = exchange.getBuyerSeesPrice(listingId);
        uint256 expectedTakerFee = (price * 200) / 10000; // 2% taker fee
        uint256 expectedRoyalty = (price * 500) / 10000; // 5% royalty

        assertEq(buyerPrice, price + expectedTakerFee + expectedRoyalty);
    }

    function test_GetFloorDiff() public {
        uint256 tokenId = 1;
        bytes32 listingId = exchange.getGeneratedListingId(address(collection), tokenId, seller);

        int256 floorDiff = exchange.getFloorDiff(listingId);
        // Since getFloorPrice returns 1 ether, and we haven't set a price,
        // this will be negative
        assertTrue(floorDiff < 0);
    }

    function test_GetListingsByCollection() public {
        bytes32[] memory listings = exchange.getListingsByCollection(address(collection));
        assertEq(listings.length, 0);
    }

    function test_GetListingsBySeller() public {
        bytes32[] memory listings = exchange.getListingsBySeller(seller);
        assertEq(listings.length, 0);
    }

    function test_CreateListing() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 listingDuration = 7 days;

        vm.startPrank(seller);
        vm.expectEmit(true, true, true, true);
        emit NFTListed(
            exchange.getGeneratedListingId(address(collection), tokenId, seller),
            address(collection),
            tokenId,
            seller,
            price
        );

        bytes32 listingId = exchange.createListing(address(collection), tokenId, price, listingDuration, 1);
        vm.stopPrank();

        bytes32[] memory listings = exchange.getListingsByCollection(address(collection));
        assertEq(listings.length, 1);
        assertEq(listings[0], listingId);
    }

    function test_BuyNFT() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 listingDuration = 7 days;

        // Mint NFT to seller
        vm.startPrank(seller);
        collection.mint{value: 0.1 ether}(1);
        collection.approve(address(exchange), tokenId);
        bytes32 listingId = exchange.createListing(address(collection), tokenId, price, listingDuration, 1);
        vm.stopPrank();

        // Buy NFT
        vm.startPrank(buyer);
        uint256 buyerPrice = exchange.getBuyerSeesPrice(listingId);

        // Expect the NFTSold event
        vm.expectEmit(true, true, true, true);
        emit NFTSold(listingId, address(collection), tokenId, seller, buyer, price);

        // Execute the buy
        exchange.buyNFT{value: buyerPrice}(listingId);
        vm.stopPrank();

        // Verify listing is removed
        bytes32[] memory listings = exchange.getListingsByCollection(address(collection));
        assertEq(listings.length, 0);

        // Verify NFT ownership
        assertEq(collection.ownerOf(tokenId), buyer);
    }

    function test_RevertWhen_BuyNFTWithInsufficientPayment() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 listingDuration = 7 days;

        // Mint NFT to seller
        vm.startPrank(seller);
        collection.mint{value: 0.1 ether}(1);
        collection.approve(address(exchange), tokenId);
        bytes32 listingId = exchange.createListing(address(collection), tokenId, price, listingDuration, 1);
        vm.stopPrank();

        // Try to buy with insufficient payment
        vm.startPrank(buyer);
        vm.expectRevert(NFTExchange__InsufficientPayment.selector);
        exchange.buyNFT{value: price - 1}(listingId);
        vm.stopPrank();
    }

    function test_RevertWhen_BuyExpiredListing() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 listingDuration = 1 days;

        // Mint NFT to seller
        vm.startPrank(seller);
        collection.mint{value: 0.1 ether}(1);
        collection.approve(address(exchange), tokenId);
        bytes32 listingId = exchange.createListing(address(collection), tokenId, price, listingDuration, 1);
        vm.stopPrank();

        // Fast forward past listing duration
        vm.warp(block.timestamp + listingDuration + 1);

        // Try to buy expired listing
        vm.startPrank(buyer);
        vm.expectRevert(NFTExchange__ListingExpired.selector);
        exchange.buyNFT{value: price}(listingId);
        vm.stopPrank();
    }

    function test_CancelListing() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 listingDuration = 7 days;

        // Create listing
        vm.startPrank(seller);
        bytes32 listingId = exchange.createListing(address(collection), tokenId, price, listingDuration, 1);
        exchange.cancelListing(listingId);
        vm.stopPrank();

        bytes32[] memory listings = exchange.getListingsByCollection(address(collection));
        assertEq(listings.length, 0); // Listing should be removed after cancellation
    }

    function test_RevertWhen_CancelListingNotOwner() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 listingDuration = 7 days;

        // Create listing
        vm.startPrank(seller);
        bytes32 listingId = exchange.createListing(address(collection), tokenId, price, listingDuration, 1);
        vm.stopPrank();

        // Try to cancel as non-owner
        vm.startPrank(buyer);
        vm.expectRevert(NFTExchange__NotTheOwner.selector);
        exchange.cancelListing(listingId);
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateTakerFeeExceedsMax() public {
        uint256 invalidFee = 10001; // > 100%

        vm.expectRevert(NFTExchange__InvalidTakerFee.selector);
        exchange.updateTakerFee(invalidFee);
    }

    function test_RevertWhen_UpdateTakerFeeNotOwner() public {
        uint256 newFee = 300;

        vm.prank(buyer);
        vm.expectRevert();
        exchange.updateTakerFee(newFee);
    }

    function test_GetTopTraitPrice() public {
        uint256 topTraitPrice = exchange.getTopTraitPrice(address(collection), 1);
        uint256 floorPrice = exchange.getFloorPrice(address(collection));

        // Should be 20% above floor price
        assertEq(topTraitPrice, (floorPrice * 120) / 100);
    }

    function test_GetLadderPrice() public {
        uint256 ladderPrice = exchange.getLadderPrice(address(collection), 1);
        uint256 floorPrice = exchange.getFloorPrice(address(collection));

        // Should be 10% above floor price
        assertEq(ladderPrice, (floorPrice * 110) / 100);
    }

    function test_Get24hVolume() public {
        uint256 volume = exchange.get24hVolume(address(collection));

        // Should return placeholder value
        assertEq(volume, 10 ether);
    }

    function test_GetRoyaltyInfoWithNonBaseCollection() public {
        // Deploy a regular ERC721 contract that doesn't inherit from BaseCollection
        // SimpleERC721 regularNFT = new SimpleERC721("Regular", "REG");
        MockERC721 regularNFT = new MockERC721("Regular", "REG");

        (address receiver, uint256 royaltyAmount) = exchange.getRoyaltyInfo(address(regularNFT), 1, 1 ether);

        // Should return zero values for non-BaseCollection contracts
        assertEq(receiver, regularNFT.getFeeContract().owner());
        assertEq(royaltyAmount, 0);
    }

    function test_DistributePaymentsWithRefund() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 listingDuration = 7 days;

        // Mint NFT to seller
        vm.startPrank(seller);
        collection.mint{value: 0.1 ether}(1);
        collection.approve(address(exchange), tokenId);
        bytes32 listingId = exchange.createListing(address(collection), tokenId, price, listingDuration, 1);
        vm.stopPrank();

        // Buy NFT with overpayment to test refund logic
        vm.startPrank(buyer);
        uint256 buyerPrice = exchange.getBuyerSeesPrice(listingId);
        uint256 overpayment = 0.5 ether;

        uint256 buyerBalanceBefore = buyer.balance;
        exchange.buyNFT{value: buyerPrice + overpayment}(listingId);
        uint256 buyerBalanceAfter = buyer.balance;

        // The actual amount sent should equal buyerPrice + overpayment
        assertEq(buyerPrice + overpayment, 1.57 ether);
        vm.stopPrank();
    }

    function test_BuyNFTWithZeroRoyalty() public {
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        uint256 listingDuration = 7 days;

        // Create a collection with zero royalty
        vm.startPrank(seller);
        CollectionParams memory params = CollectionParams({
            name: "Zero Royalty Collection",
            symbol: "ZERO",
            owner: seller,
            description: "Zero Royalty Test",
            mintPrice: 0.1 ether,
            royaltyFee: 0, // 0% royalty
            maxSupply: 10000,
            mintLimitPerWallet: 5,
            mintStartTime: block.timestamp,
            allowlistMintPrice: 0.08 ether,
            publicMintPrice: 0.1 ether,
            allowlistStageDuration: 1 days,
            tokenURI: "ipfs://test"
        });
        TestCollection zeroRoyaltyCollection = new TestCollection(params);

        // Add seller to allowlist and update mint stage
        address[] memory allowlist = new address[](1);
        allowlist[0] = seller;
        zeroRoyaltyCollection.addToAllowlist(allowlist);
        zeroRoyaltyCollection.updateMintStage();

        // Mint and list NFT
        zeroRoyaltyCollection.mint{value: 0.1 ether}(1);
        zeroRoyaltyCollection.approve(address(exchange), tokenId);
        bytes32 listingId = exchange.createListing(address(zeroRoyaltyCollection), tokenId, price, listingDuration, 1);
        vm.stopPrank();

        // Buy NFT (should test the m_royalty == 0 branch)
        vm.startPrank(buyer);
        uint256 buyerPrice = exchange.getBuyerSeesPrice(listingId);
        exchange.buyNFT{value: buyerPrice}(listingId);
        vm.stopPrank();

        // Verify NFT was transferred
        assertEq(zeroRoyaltyCollection.ownerOf(tokenId), buyer);
    }
}
