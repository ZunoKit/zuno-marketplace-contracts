// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {AdvancedListingManager} from "src/core/listing/AdvancedListingManager.sol";
import {MarketplaceAccessControl} from "src/core/access/MarketplaceAccessControl.sol";
import {MarketplaceValidator} from "src/core/validation/MarketplaceValidator.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC1155} from "test/mocks/MockERC1155.sol";

import "src/types/ListingTypes.sol";
import "src/errors/AdvancedListingErrors.sol";
import "src/events/AdvancedListingEvents.sol";

/**
 * @title AdvancedListingManagerTest
 * @notice Comprehensive unit tests for AdvancedListingManager contract
 * @dev Tests all listing types, purchase flows, and management features
 */
contract AdvancedListingManagerTest is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    AdvancedListingManager public listingManager;
    MarketplaceAccessControl public accessControl;
    MarketplaceValidator public validator;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    address public owner;
    address public admin;
    address public seller;
    address public buyer;
    address public user1;
    address public user2;
    address public feeRecipient;

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant QUANTITY = 5;
    uint256 public constant PRICE = 1 ether;
    uint256 public constant DURATION = 7 days;

    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        // Setup test accounts
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        feeRecipient = makeAddr("feeRecipient");

        // Deploy contracts as owner
        vm.startPrank(owner);

        // Deploy access control
        accessControl = new MarketplaceAccessControl();

        // Deploy validator
        validator = new MarketplaceValidator();

        // Deploy listing manager
        listingManager = new AdvancedListingManager(address(accessControl), address(validator));

        // Deploy mock NFTs
        mockERC721 = new MockERC721("Test NFT", "TEST");
        mockERC1155 = new MockERC1155("Test ERC1155", "T1155");

        // Setup supported contracts
        listingManager.setSupportedContract(address(mockERC721), true);
        listingManager.setSupportedContract(address(mockERC1155), true);

        vm.stopPrank();

        // Setup test NFTs
        vm.startPrank(seller);
        mockERC721.mint(seller, TOKEN_ID);
        mockERC721.setApprovalForAll(address(listingManager), true);

        mockERC1155.mint(seller, TOKEN_ID, QUANTITY, "");
        mockERC1155.setApprovalForAll(address(listingManager), true);
        vm.stopPrank();

        // Fund buyer
        vm.deal(buyer, 10 ether);
    }

    // ============================================================================
    // CONSTRUCTOR TESTS
    // ============================================================================

    function test_Constructor_Success() public {
        assertEq(address(listingManager.accessControl()), address(accessControl));
        assertEq(address(listingManager.validator()), address(validator));
        assertEq(listingManager.owner(), owner);

        // Check default settings
        ListingFees memory fees = listingManager.getListingFees();
        assertEq(fees.percentageFee, 250); // 2.5%
        assertEq(fees.feeRecipient, owner);

        TimeConstraints memory constraints = listingManager.getTimeConstraints();
        assertEq(constraints.minListingDuration, MIN_LISTING_DURATION);
        assertEq(constraints.maxListingDuration, MAX_LISTING_DURATION);
    }

    function test_Constructor_RevertZeroAddress() public {
        vm.expectRevert(AdvancedListing__ZeroAddress.selector);
        new AdvancedListingManager(address(0), address(validator));

        vm.expectRevert(AdvancedListing__ZeroAddress.selector);
        new AdvancedListingManager(address(accessControl), address(0));
    }

    // ============================================================================
    // FIXED PRICE LISTING TESTS
    // ============================================================================

    function test_CreateFixedPriceListing_Success() public {
        vm.startPrank(seller);

        vm.expectEmit(false, true, true, false); // Don't check listingId and data
        emit ListingCreated(
            bytes32(0), // Will be generated
            ListingType.FIXED_PRICE,
            seller,
            address(mockERC721),
            TOKEN_ID,
            1,
            PRICE,
            0, // Don't check exact timestamp
            0 // Don't check exact timestamp
        );

        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);

        // Verify listing was created
        Listing memory listing = listingManager.getListing(listingId);
        assertTrue(listing.listingType == ListingType.FIXED_PRICE);
        assertTrue(listing.status == ListingStatus.ACTIVE);
        assertEq(listing.seller, seller);
        assertEq(listing.nftContract, address(mockERC721));
        assertEq(listing.tokenId, TOKEN_ID);
        assertEq(listing.price, PRICE);
        assertTrue(listing.acceptOffers);

        // Check mappings
        bytes32[] memory userListings = listingManager.getUserListings(seller);
        assertEq(userListings.length, 1);
        assertEq(userListings[0], listingId);
    }

    function test_CreateFixedPriceListing_RevertZeroAddress() public {
        vm.startPrank(seller);

        vm.expectRevert(AdvancedListing__ZeroAddress.selector);
        listingManager.createFixedPriceListing(address(0), TOKEN_ID, 1, PRICE, DURATION, true);
    }

    function test_CreateFixedPriceListing_RevertUnsupportedContract() public {
        vm.startPrank(seller);

        address unsupportedContract = makeAddr("unsupported");

        vm.expectRevert(AdvancedListing__UnsupportedNFTContract.selector);
        listingManager.createFixedPriceListing(unsupportedContract, TOKEN_ID, 1, PRICE, DURATION, true);
    }

    function test_CreateFixedPriceListing_RevertInvalidPrice() public {
        vm.startPrank(seller);

        vm.expectRevert(AdvancedListing__InvalidPrice.selector);
        listingManager.createFixedPriceListing(
            address(mockERC721),
            TOKEN_ID,
            1,
            0, // Invalid price
            DURATION,
            true
        );
    }

    function test_CreateFixedPriceListing_RevertInvalidDuration() public {
        vm.startPrank(seller);

        vm.expectRevert(AdvancedListing__InvalidDuration.selector);
        listingManager.createFixedPriceListing(
            address(mockERC721),
            TOKEN_ID,
            1,
            PRICE,
            30 minutes, // Too short
            true
        );
    }

    function test_CreateFixedPriceListing_RevertNotOwner() public {
        vm.startPrank(user1); // Not the owner

        vm.expectRevert(AdvancedListing__NotTokenOwner.selector);
        listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);
    }

    function test_CreateFixedPriceListing_RevertNotApproved() public {
        // Mint new token to seller but don't approve
        vm.startPrank(seller);
        mockERC721.mint(seller, 999);
        // Revoke approval for all
        mockERC721.setApprovalForAll(address(listingManager), false);

        vm.expectRevert(AdvancedListing__NotApproved.selector);
        listingManager.createFixedPriceListing(address(mockERC721), 999, 1, PRICE, DURATION, true);
    }

    function test_CreateFixedPriceListing_RevertTokenAlreadyListed() public {
        vm.startPrank(seller);

        // Create first listing
        listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);

        // Try to create second listing for same token
        vm.expectRevert(AdvancedListing__TokenAlreadyListed.selector);
        listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);
    }

    // ============================================================================
    // AUCTION LISTING TESTS
    // ============================================================================

    function test_CreateAuctionListing_Success() public {
        vm.startPrank(seller);

        AuctionParams memory params = AuctionParams({
            startingPrice: 0.5 ether,
            reservePrice: 1 ether,
            buyNowPrice: 2 ether,
            bidIncrement: 500, // 5% in basis points
            duration: 3 days,
            extendOnBid: true,
            extensionTime: 15 minutes
        });

        vm.expectEmit(false, true, true, false); // Don't check listingId and data
        emit ListingCreated(
            bytes32(0), // Will be generated
            ListingType.AUCTION,
            seller,
            address(mockERC721),
            TOKEN_ID,
            1,
            params.startingPrice,
            0, // Don't check exact timestamp
            0 // Don't check exact timestamp
        );

        bytes32 listingId = listingManager.createAuctionListing(address(mockERC721), TOKEN_ID, 1, params);

        // Verify listing was created
        Listing memory listing = listingManager.getListing(listingId);
        assertTrue(listing.listingType == ListingType.AUCTION);
        assertTrue(listing.status == ListingStatus.ACTIVE);
        assertEq(listing.price, params.startingPrice);
        assertFalse(listing.acceptOffers); // Auctions don't accept direct offers

        // Verify auction params
        AuctionParams memory storedParams = listingManager.getAuctionParams(listingId);
        assertEq(storedParams.startingPrice, params.startingPrice);
        assertEq(storedParams.reservePrice, params.reservePrice);
        assertEq(storedParams.buyNowPrice, params.buyNowPrice);
    }

    function test_CreateAuctionListing_RevertInvalidParams() public {
        vm.startPrank(seller);

        // Invalid: reserve price less than starting price
        AuctionParams memory params = AuctionParams({
            startingPrice: 1 ether,
            reservePrice: 0.5 ether, // Less than starting price
            buyNowPrice: 2 ether,
            bidIncrement: 500, // 5% in basis points
            duration: 3 days,
            extendOnBid: true,
            extensionTime: 15 minutes
        });

        vm.expectRevert(AdvancedListing__InvalidAuctionParams.selector);
        listingManager.createAuctionListing(address(mockERC721), TOKEN_ID, 1, params);
    }

    // ============================================================================
    // DUTCH AUCTION LISTING TESTS
    // ============================================================================

    function test_CreateDutchAuctionListing_Success() public {
        vm.startPrank(seller);

        DutchAuctionParams memory params = DutchAuctionParams({
            startingPrice: 2 ether,
            endingPrice: 0.5 ether,
            duration: 24 hours,
            priceDropInterval: 1 hours,
            priceDropAmount: 0.1 ether
        });

        bytes32 listingId = listingManager.createDutchAuctionListing(address(mockERC721), TOKEN_ID, 1, params);

        // Verify listing was created
        Listing memory listing = listingManager.getListing(listingId);
        assertTrue(listing.listingType == ListingType.DUTCH_AUCTION);
        assertEq(listing.price, params.startingPrice);

        // Verify Dutch auction params
        DutchAuctionParams memory storedParams = listingManager.getDutchAuctionParams(listingId);
        assertEq(storedParams.startingPrice, params.startingPrice);
        assertEq(storedParams.endingPrice, params.endingPrice);
    }

    function test_CreateDutchAuctionListing_RevertInvalidParams() public {
        vm.startPrank(seller);

        // Invalid: starting price less than ending price
        DutchAuctionParams memory params = DutchAuctionParams({
            startingPrice: 0.5 ether,
            endingPrice: 2 ether, // Greater than starting price
            duration: 24 hours,
            priceDropInterval: 1 hours,
            priceDropAmount: 0.1 ether
        });

        vm.expectRevert(AdvancedListing__InvalidDutchAuctionParams.selector);
        listingManager.createDutchAuctionListing(address(mockERC721), TOKEN_ID, 1, params);
    }

    // ============================================================================
    // PURCHASE TESTS
    // ============================================================================

    function test_BuyNow_Success() public {
        // Set royalty to 2.5% to match test expectations
        vm.prank(owner);
        mockERC721.setDefaultRoyalty(owner, 250); // 2.5%

        // Create listing
        vm.startPrank(seller);
        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);
        vm.stopPrank();

        // Purchase
        vm.startPrank(buyer);

        uint256 sellerBalanceBefore = seller.balance;
        uint256 buyerBalanceBefore = buyer.balance;

        vm.expectEmit(true, true, true, false); // Don't check data
        emit NFTPurchased(
            listingId,
            buyer,
            seller,
            address(mockERC721),
            TOKEN_ID,
            1,
            PRICE,
            0, // Will calculate fees
            0 // Don't check exact timestamp
        );

        listingManager.buyNow{value: PRICE}(listingId);

        // Verify NFT transfer
        assertEq(mockERC721.ownerOf(TOKEN_ID), buyer);

        // Verify listing status
        Listing memory listing = listingManager.getListing(listingId);
        assertTrue(listing.status == ListingStatus.SOLD);

        // Verify payment (minus fees and royalties)
        uint256 marketplaceFees = (PRICE * 250) / 10000; // 2.5% marketplace fee
        uint256 royalties = (PRICE * 250) / 10000; // 2.5% royalties (from MockERC721)
        assertEq(seller.balance, sellerBalanceBefore + PRICE - marketplaceFees - royalties);
        assertEq(buyer.balance, buyerBalanceBefore - PRICE);
    }

    function test_BuyNow_RevertIncorrectPayment() public {
        // Create listing
        vm.startPrank(seller);
        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);
        vm.stopPrank();

        // Try to purchase with wrong amount
        vm.startPrank(buyer);
        vm.expectRevert(AdvancedListing__IncorrectPayment.selector);
        listingManager.buyNow{value: PRICE - 1}(listingId);
    }

    function test_BuyNow_RevertCannotBuyOwnListing() public {
        // Create listing
        vm.startPrank(seller);
        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);
        vm.stopPrank();

        // Give seller enough ETH to attempt purchase
        vm.deal(seller, PRICE);

        // Try to buy own listing
        vm.startPrank(seller);
        vm.expectRevert(AdvancedListing__CannotBuyOwnListing.selector);
        listingManager.buyNow{value: PRICE}(listingId);
        vm.stopPrank();
    }

    function test_BuyNow_RevertUnsupportedListingType() public {
        // Create auction listing
        vm.startPrank(seller);
        AuctionParams memory params = AuctionParams({
            startingPrice: 0.5 ether,
            reservePrice: 1 ether,
            buyNowPrice: 0, // No buy now
            bidIncrement: 500, // 5% in basis points
            duration: 3 days,
            extendOnBid: true,
            extensionTime: 15 minutes
        });

        bytes32 listingId = listingManager.createAuctionListing(address(mockERC721), TOKEN_ID, 1, params);
        vm.stopPrank();

        // Try to buy now on auction
        vm.startPrank(buyer);
        vm.expectRevert(AdvancedListing__UnsupportedListingType.selector);
        listingManager.buyNow{value: PRICE}(listingId);
    }

    // ============================================================================
    // DUTCH AUCTION PURCHASE TESTS
    // ============================================================================

    function test_GetCurrentDutchAuctionPrice_Success() public {
        vm.startPrank(seller);

        DutchAuctionParams memory params = DutchAuctionParams({
            startingPrice: 2 ether,
            endingPrice: 0.5 ether,
            duration: 10 hours,
            priceDropInterval: 1 hours,
            priceDropAmount: 0.15 ether
        });

        bytes32 listingId = listingManager.createDutchAuctionListing(address(mockERC721), TOKEN_ID, 1, params);
        vm.stopPrank();

        // Check initial price
        uint256 currentPrice = listingManager.getCurrentDutchAuctionPrice(listingId);
        assertEq(currentPrice, 2 ether);

        // Advance time by 2 hours
        vm.warp(block.timestamp + 2 hours);
        currentPrice = listingManager.getCurrentDutchAuctionPrice(listingId);
        assertEq(currentPrice, 1.7 ether); // 2 - (2 * 0.15)

        // Advance time to end
        vm.warp(block.timestamp + 10 hours);
        currentPrice = listingManager.getCurrentDutchAuctionPrice(listingId);
        assertEq(currentPrice, 0.5 ether); // Should be ending price
    }

    function test_BuyDutchAuction_Success() public {
        vm.startPrank(seller);

        DutchAuctionParams memory params = DutchAuctionParams({
            startingPrice: 2 ether,
            endingPrice: 0.5 ether,
            duration: 10 hours,
            priceDropInterval: 1 hours,
            priceDropAmount: 0.15 ether
        });

        bytes32 listingId = listingManager.createDutchAuctionListing(address(mockERC721), TOKEN_ID, 1, params);
        vm.stopPrank();

        // Advance time by 1 hour
        vm.warp(block.timestamp + 1 hours);
        uint256 currentPrice = listingManager.getCurrentDutchAuctionPrice(listingId);
        assertEq(currentPrice, 1.85 ether);

        // Purchase at current price
        vm.startPrank(buyer);
        listingManager.buyDutchAuction{value: currentPrice}(listingId);

        // Verify NFT transfer
        assertEq(mockERC721.ownerOf(TOKEN_ID), buyer);

        // Verify listing status
        Listing memory listing = listingManager.getListing(listingId);
        assertTrue(listing.status == ListingStatus.SOLD);
    }

    function test_BuyDutchAuction_RevertIncorrectPayment() public {
        vm.startPrank(seller);

        DutchAuctionParams memory params = DutchAuctionParams({
            startingPrice: 2 ether,
            endingPrice: 0.5 ether,
            duration: 10 hours,
            priceDropInterval: 1 hours,
            priceDropAmount: 0.15 ether
        });

        bytes32 listingId = listingManager.createDutchAuctionListing(address(mockERC721), TOKEN_ID, 1, params);
        vm.stopPrank();

        // Try to purchase with wrong amount
        vm.startPrank(buyer);
        vm.expectRevert(AdvancedListing__IncorrectPayment.selector);
        listingManager.buyDutchAuction{value: 1 ether}(listingId);
    }

    // ============================================================================
    // LISTING MANAGEMENT TESTS
    // ============================================================================

    function test_UpdateListing_Success() public {
        vm.startPrank(seller);

        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);

        uint256 newPrice = 2 ether;
        uint256 newEndTime = block.timestamp + 14 days;

        vm.expectEmit(true, true, true, true);
        emit ListingUpdated(listingId, seller, PRICE, newPrice, block.timestamp + DURATION, newEndTime, block.timestamp);

        listingManager.updateListing(listingId, newPrice, newEndTime);

        // Verify updates
        Listing memory listing = listingManager.getListing(listingId);
        assertEq(listing.price, newPrice);
        assertEq(listing.endTime, newEndTime);
    }

    function test_UpdateListing_RevertNotSeller() public {
        vm.startPrank(seller);
        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(AdvancedListing__NotSeller.selector);
        listingManager.updateListing(listingId, 2 ether, 0);
    }

    function test_UpdateListing_RevertUnsupportedListingType() public {
        vm.startPrank(seller);

        AuctionParams memory params = AuctionParams({
            startingPrice: 0.5 ether,
            reservePrice: 1 ether,
            buyNowPrice: 2 ether,
            bidIncrement: 500, // 5% in basis points
            duration: 3 days,
            extendOnBid: true,
            extensionTime: 15 minutes
        });

        bytes32 listingId = listingManager.createAuctionListing(address(mockERC721), TOKEN_ID, 1, params);

        vm.expectRevert(AdvancedListing__UnsupportedListingType.selector);
        listingManager.updateListing(listingId, 2 ether, 0);
    }

    function test_CancelListing_Success() public {
        vm.startPrank(seller);

        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);

        vm.expectEmit(true, true, true, true);
        emit ListingCancelled(listingId, seller, "Changed mind", block.timestamp);

        listingManager.cancelListing(listingId, "Changed mind");

        // Verify cancellation
        Listing memory listing = listingManager.getListing(listingId);
        assertTrue(listing.status == ListingStatus.CANCELLED);

        // Verify statistics
        SellerStats memory stats = listingManager.getSellerStats(seller);
        assertEq(stats.cancelledListings, 1);
    }

    function test_CancelListing_RevertNotSeller() public {
        vm.startPrank(seller);
        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(AdvancedListing__NotSeller.selector);
        listingManager.cancelListing(listingId, "Unauthorized");
    }

    // ============================================================================
    // VIEW FUNCTION TESTS
    // ============================================================================

    function test_GetListing_Success() public {
        vm.startPrank(seller);
        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);

        Listing memory listing = listingManager.getListing(listingId);
        assertEq(listing.listingId, listingId);
        assertEq(listing.seller, seller);
        assertEq(listing.nftContract, address(mockERC721));
        assertEq(listing.tokenId, TOKEN_ID);
        assertEq(listing.price, PRICE);
    }

    function test_GetUserListings_Success() public {
        vm.startPrank(seller);

        // Create multiple listings
        bytes32 listingId1 =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);

        // Mint and list another token
        mockERC721.mint(seller, 2);
        bytes32 listingId2 = listingManager.createFixedPriceListing(address(mockERC721), 2, 1, PRICE, DURATION, true);

        bytes32[] memory userListings = listingManager.getUserListings(seller);
        assertEq(userListings.length, 2);
        assertEq(userListings[0], listingId1);
        assertEq(userListings[1], listingId2);
    }

    function test_GetGlobalStats_Success() public {
        vm.startPrank(seller);
        listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);

        ListingStats memory stats = listingManager.getGlobalStats();
        assertEq(stats.totalListings, 1);
        assertEq(stats.activeListings, 1);
        assertEq(stats.soldListings, 0);
    }

    // ============================================================================
    // ADMIN FUNCTION TESTS
    // ============================================================================

    function test_SetSupportedContract_Success() public {
        address newContract = makeAddr("newContract");

        vm.startPrank(owner);
        listingManager.setSupportedContract(newContract, true);

        assertTrue(listingManager.isContractSupported(newContract));
    }

    function test_SetSupportedContract_RevertZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(AdvancedListing__ZeroAddress.selector);
        listingManager.setSupportedContract(address(0), true);
    }

    function test_UpdateListingFees_Success() public {
        vm.startPrank(owner);

        ListingFees memory newFees = ListingFees({
            baseFee: 0.001 ether,
            percentageFee: 300, // 3%
            auctionFee: 100,
            bundleFee: 150,
            offerFee: 0.002 ether,
            feeRecipient: feeRecipient
        });

        listingManager.updateListingFees(newFees);

        ListingFees memory updatedFees = listingManager.getListingFees();
        assertEq(updatedFees.percentageFee, 300);
        assertEq(updatedFees.feeRecipient, feeRecipient);
    }

    function test_UpdateListingFees_RevertFeeTooHigh() public {
        vm.startPrank(owner);

        ListingFees memory newFees = ListingFees({
            baseFee: 0,
            percentageFee: 1500, // 15% - too high
            auctionFee: 0,
            bundleFee: 0,
            offerFee: 0,
            feeRecipient: feeRecipient
        });

        vm.expectRevert(AdvancedListing__FeeTooHigh.selector);
        listingManager.updateListingFees(newFees);
    }

    function test_EmergencyPause_Success() public {
        // Grant emergency role to admin
        vm.startPrank(owner);
        accessControl.grantRoleWithReason(accessControl.EMERGENCY_ROLE(), admin, "Test emergency role");
        vm.stopPrank();

        vm.startPrank(admin);
        listingManager.emergencyPause("Emergency test");

        assertTrue(listingManager.paused());
    }

    function test_Unpause_Success() public {
        // Pause first
        vm.startPrank(owner);
        accessControl.grantRoleWithReason(accessControl.EMERGENCY_ROLE(), admin, "Test emergency role");
        vm.stopPrank();

        vm.startPrank(admin);
        listingManager.emergencyPause("Test");
        vm.stopPrank();

        // Unpause
        vm.startPrank(owner);
        listingManager.unpause();

        assertFalse(listingManager.paused());
    }

    // ============================================================================
    // INTEGRATION TESTS
    // ============================================================================

    function test_Integration_CompleteListingLifecycle() public {
        // 1. Create listing
        vm.startPrank(seller);
        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION, true);
        vm.stopPrank();

        // 2. Update listing
        vm.startPrank(seller);
        listingManager.updateListing(listingId, 1.5 ether, 0);
        vm.stopPrank();

        // 3. Purchase
        vm.startPrank(buyer);
        listingManager.buyNow{value: 1.5 ether}(listingId);
        vm.stopPrank();

        // 4. Verify final state
        Listing memory listing = listingManager.getListing(listingId);
        assertTrue(listing.status == ListingStatus.SOLD);
        assertEq(mockERC721.ownerOf(TOKEN_ID), buyer);

        // 5. Check statistics
        ListingStats memory globalStats = listingManager.getGlobalStats();
        assertEq(globalStats.soldListings, 1);
        assertEq(globalStats.activeListings, 0);

        SellerStats memory sellerStats = listingManager.getSellerStats(seller);
        assertEq(sellerStats.successfulSales, 1);

        BuyerStats memory buyerStats = listingManager.getBuyerStats(buyer);
        assertEq(buyerStats.totalPurchases, 1);
    }

    // ============================================================================
    // FUZZ TESTS
    // ============================================================================

    function testFuzz_CreateFixedPriceListing(uint256 price, uint256 duration) public {
        vm.assume(price > 0 && price <= 100 ether);
        vm.assume(duration >= MIN_LISTING_DURATION && duration <= MAX_LISTING_DURATION);

        vm.startPrank(seller);

        // Mint new token for each test
        uint256 tokenId = 1000 + (price % 1000);
        mockERC721.mint(seller, tokenId);

        bytes32 listingId =
            listingManager.createFixedPriceListing(address(mockERC721), tokenId, 1, price, duration, true);

        Listing memory listing = listingManager.getListing(listingId);
        assertEq(listing.price, price);
        assertEq(listing.endTime, block.timestamp + duration);
    }

    function testFuzz_DutchAuctionPrice(uint256 startingPrice, uint256 endingPrice, uint256 timeElapsed) public {
        vm.assume(startingPrice > endingPrice);
        vm.assume(endingPrice > 0);
        vm.assume(startingPrice <= 100 ether);
        vm.assume(timeElapsed <= 24 hours);

        // Ensure price difference is large enough to avoid zero priceDropAmount
        vm.assume(startingPrice - endingPrice >= 24);

        vm.startPrank(seller);

        // Mint new token
        uint256 tokenId = 2000 + (startingPrice % 1000);
        mockERC721.mint(seller, tokenId);

        uint256 priceDropAmount = (startingPrice - endingPrice) / 24;
        // Ensure priceDropAmount is not zero
        if (priceDropAmount == 0) {
            priceDropAmount = 1;
        }

        DutchAuctionParams memory params = DutchAuctionParams({
            startingPrice: startingPrice,
            endingPrice: endingPrice,
            duration: 24 hours,
            priceDropInterval: 1 hours,
            priceDropAmount: priceDropAmount
        });

        bytes32 listingId = listingManager.createDutchAuctionListing(address(mockERC721), tokenId, 1, params);
        vm.stopPrank();

        // Advance time
        vm.warp(block.timestamp + timeElapsed);

        uint256 currentPrice = listingManager.getCurrentDutchAuctionPrice(listingId);

        // Price should be between ending and starting price
        assertGe(currentPrice, endingPrice);
        assertLe(currentPrice, startingPrice);
    }
}
