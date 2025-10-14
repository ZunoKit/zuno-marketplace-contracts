// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/libraries/BatchOperationsLib.sol";
import "src/libraries/NFTValidationLib.sol";
import "test/mocks/MockERC721.sol";
import "test/mocks/MockERC1155.sol";

/**
 * @title BatchOperationsLibTest
 * @notice Comprehensive tests for BatchOperationsLib library functions
 */
contract BatchOperationsLibTest is Test {
    using BatchOperationsLib for *;

    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    address public seller = address(0x1);
    address public spender = address(0x2);
    address public buyer = address(0x3);

    function setUp() public {
        mockERC721 = new MockERC721("Test NFT", "TNFT");
        mockERC1155 = new MockERC1155("Test 1155", "T1155");

        // Mint tokens to seller
        for (uint256 i = 1; i <= 5; i++) {
            mockERC721.mint(seller, i);
            mockERC1155.mint(seller, i, 10);
        }

        // Set approvals
        vm.startPrank(seller);
        mockERC721.setApprovalForAll(spender, true);
        mockERC1155.setApprovalForAll(spender, true);
        vm.stopPrank();

        // Fund buyer
        vm.deal(buyer, 100 ether);
    }

    // ============================================================================
    // BATCH LISTING VALIDATION TESTS
    // ============================================================================

    function testValidateBatchListing_Success() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        uint256[] memory prices = new uint256[](3);
        prices[0] = 1 ether;
        prices[1] = 2 ether;
        prices[2] = 3 ether;

        BatchOperationsLib.BatchListingParams memory params = BatchOperationsLib.BatchListingParams({
            nftContract: address(mockERC721),
            tokenIds: tokenIds,
            amounts: amounts,
            prices: prices,
            listingDuration: 1 days,
            seller: seller,
            spender: spender
        });

        (bool isValid, string memory errorMessage) = BatchOperationsLib.validateBatchListing(params);

        assertTrue(isValid);
        assertEq(bytes(errorMessage).length, 0);
    }

    function testValidateBatchListing_EmptyArrays() public {
        uint256[] memory emptyArray = new uint256[](0);

        BatchOperationsLib.BatchListingParams memory params = BatchOperationsLib.BatchListingParams({
            nftContract: address(mockERC721),
            tokenIds: emptyArray,
            amounts: emptyArray,
            prices: emptyArray,
            listingDuration: 1 days,
            seller: seller,
            spender: spender
        });

        (bool isValid, string memory errorMessage) = BatchOperationsLib.validateBatchListing(params);

        assertFalse(isValid);
        assertEq(errorMessage, "");
    }

    function testValidateBatchListing_ArrayLengthMismatch() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        uint256[] memory amounts = new uint256[](2); // Different length
        amounts[0] = 1;
        amounts[1] = 1;

        uint256[] memory prices = new uint256[](3);
        prices[0] = 1 ether;
        prices[1] = 2 ether;
        prices[2] = 3 ether;

        BatchOperationsLib.BatchListingParams memory params = BatchOperationsLib.BatchListingParams({
            nftContract: address(mockERC721),
            tokenIds: tokenIds,
            amounts: amounts,
            prices: prices,
            listingDuration: 1 days,
            seller: seller,
            spender: spender
        });

        (bool isValid, string memory errorMessage) = BatchOperationsLib.validateBatchListing(params);

        assertFalse(isValid);
        assertEq(errorMessage, "");
    }

    function testValidateBatchListing_InvalidNFT() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 999; // Non-existent token

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint256[] memory prices = new uint256[](2);
        prices[0] = 1 ether;
        prices[1] = 1 ether;

        BatchOperationsLib.BatchListingParams memory params = BatchOperationsLib.BatchListingParams({
            nftContract: address(mockERC721),
            tokenIds: tokenIds,
            amounts: amounts,
            prices: prices,
            listingDuration: 1 days,
            seller: seller,
            spender: spender
        });

        (bool isValid, string memory errorMessage) = BatchOperationsLib.validateBatchListing(params);

        assertFalse(isValid);
        assertTrue(bytes(errorMessage).length > 0);
        // Error should contain "Token 1:" since it's the second token (index 1)
        assertTrue(bytes(errorMessage).length > 8);
    }

    function testValidateBatchListing_ZeroPrice() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint256[] memory prices = new uint256[](2);
        prices[0] = 1 ether;
        prices[1] = 0; // Zero price

        BatchOperationsLib.BatchListingParams memory params = BatchOperationsLib.BatchListingParams({
            nftContract: address(mockERC721),
            tokenIds: tokenIds,
            amounts: amounts,
            prices: prices,
            listingDuration: 1 days,
            seller: seller,
            spender: spender
        });

        (bool isValid, string memory errorMessage) = BatchOperationsLib.validateBatchListing(params);

        assertFalse(isValid);
        assertEq(errorMessage, "");
    }

    function testValidateBatchListing_ZeroAmount() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 0; // Zero amount

        uint256[] memory prices = new uint256[](2);
        prices[0] = 1 ether;
        prices[1] = 1 ether;

        BatchOperationsLib.BatchListingParams memory params = BatchOperationsLib.BatchListingParams({
            nftContract: address(mockERC721),
            tokenIds: tokenIds,
            amounts: amounts,
            prices: prices,
            listingDuration: 1 days,
            seller: seller,
            spender: spender
        });

        (bool isValid, string memory errorMessage) = BatchOperationsLib.validateBatchListing(params);

        assertFalse(isValid);
        assertEq(errorMessage, "");
    }

    // ============================================================================
    // UTILITY FUNCTION TESTS
    // ============================================================================

    function testCreateListingData() public {
        BatchOperationsLib.ListingData memory listingData =
            BatchOperationsLib.createListingData(address(mockERC721), 1, 1, 1 ether, seller);

        assertEq(listingData.contractAddress, address(mockERC721));
        assertEq(listingData.tokenId, 1);
        assertEq(listingData.amount, 1);
        assertEq(listingData.price, 1 ether);
        assertEq(listingData.seller, seller);
        assertTrue(listingData.isValid);
        assertEq(bytes(listingData.errorMessage).length, 0);
    }

    function testValidateSameCollection_Success() public {
        BatchOperationsLib.ListingData[] memory listings = new BatchOperationsLib.ListingData[](2);
        listings[0] = BatchOperationsLib.createListingData(address(mockERC721), 1, 1, 1 ether, seller);
        listings[1] = BatchOperationsLib.createListingData(address(mockERC721), 2, 1, 2 ether, seller);

        (bool isValid, address collection) = BatchOperationsLib.validateSameCollection(listings);

        assertTrue(isValid);
        assertEq(collection, address(mockERC721));
    }

    function testValidateSameCollection_DifferentCollections() public {
        BatchOperationsLib.ListingData[] memory listings = new BatchOperationsLib.ListingData[](2);
        listings[0] = BatchOperationsLib.createListingData(address(mockERC721), 1, 1, 1 ether, seller);
        listings[1] = BatchOperationsLib.createListingData(address(mockERC1155), 2, 1, 2 ether, seller);

        (bool isValid, address collection) = BatchOperationsLib.validateSameCollection(listings);

        assertFalse(isValid);
        assertEq(collection, address(0));
    }

    function testValidateSameCollection_EmptyArray() public {
        BatchOperationsLib.ListingData[] memory emptyListings = new BatchOperationsLib.ListingData[](0);

        (bool isValid, address collection) = BatchOperationsLib.validateSameCollection(emptyListings);

        assertFalse(isValid);
        assertEq(collection, address(0));
    }

    // ============================================================================
    // BATCH PROCESSING TESTS
    // ============================================================================

    function testProcessBatchListing() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        uint256[] memory prices = new uint256[](3);
        prices[0] = 1 ether;
        prices[1] = 2 ether;
        prices[2] = 3 ether;

        BatchOperationsLib.BatchListingParams memory params = BatchOperationsLib.BatchListingParams({
            nftContract: address(mockERC721),
            tokenIds: tokenIds,
            amounts: amounts,
            prices: prices,
            listingDuration: 1 days,
            seller: seller,
            spender: spender
        });

        bytes32[] memory listingIds = BatchOperationsLib.processBatchListing(params);

        assertEq(listingIds.length, 3);

        // Each listing ID should be unique
        assertTrue(listingIds[0] != listingIds[1]);
        assertTrue(listingIds[1] != listingIds[2]);
        assertTrue(listingIds[0] != listingIds[2]);

        // Each listing ID should be non-zero
        assertTrue(listingIds[0] != bytes32(0));
        assertTrue(listingIds[1] != bytes32(0));
        assertTrue(listingIds[2] != bytes32(0));
    }

    // ============================================================================
    // HELPER FUNCTION TESTS
    // ============================================================================

    function testGenerateListingId() public {
        bytes32 listingId1 = BatchOperationsLib.generateListingId(address(mockERC721), 1, seller, block.timestamp);

        bytes32 listingId2 = BatchOperationsLib.generateListingId(address(mockERC721), 1, seller, block.timestamp + 1);

        assertTrue(listingId1 != bytes32(0));
        assertTrue(listingId2 != bytes32(0));
        assertTrue(listingId1 != listingId2); // Different timestamps should produce different IDs
    }

    function testGenerateListingId_Deterministic() public {
        bytes32 listingId1 = BatchOperationsLib.generateListingId(address(mockERC721), 1, seller, 12345);

        bytes32 listingId2 = BatchOperationsLib.generateListingId(address(mockERC721), 1, seller, 12345);

        assertEq(listingId1, listingId2); // Same parameters should produce same ID
    }
}
