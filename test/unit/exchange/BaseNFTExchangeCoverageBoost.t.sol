// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {BaseNFTExchange} from "src/common/BaseNFTExchange.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC1155} from "test/mocks/MockERC1155.sol";
import "src/errors/NFTExchangeErrors.sol";
import "src/events/NFTExchangeEvents.sol";

/**
 * @title BaseNFTExchangeCoverageBoostTest
 * @notice Additional tests to boost BaseNFTExchange coverage to >90%
 * @dev Focuses on edge cases and branch coverage
 */
contract BaseNFTExchangeCoverageBoostTest is Test {
    CoverageTestableBaseNFTExchange testableExchange;
    MockERC721 mockERC721;
    MockERC1155 mockERC1155;

    address constant MARKETPLACE_WALLET = address(0x123);
    address constant SELLER = address(0x456);
    address constant BUYER = address(0x789);

    function setUp() public {
        // Deploy contracts
        mockERC721 = new MockERC721("Test NFT", "TNFT");
        mockERC1155 = new MockERC1155("Test 1155", "T1155");

        // Deploy testable exchange
        testableExchange = new CoverageTestableBaseNFTExchange();
        testableExchange.initialize(MARKETPLACE_WALLET, address(this));

        // Setup test NFTs
        mockERC721.mint(SELLER, 1);
        mockERC1155.mint(SELLER, 1, 10);

        // Fund accounts
        vm.deal(BUYER, 100 ether);
        vm.deal(SELLER, 100 ether);
    }

    // ============================================================================
    // ADMIN FUNCTION EDGE CASES
    // ============================================================================

    function test_UpdateTakerFee_EdgeCases() public {
        // Test setting to 0
        testableExchange.updateTakerFee(0);
        assertEq(testableExchange.getTakerFee(), 0);

        // Test setting to maximum (100%)
        testableExchange.updateTakerFee(10000);
        assertEq(testableExchange.getTakerFee(), 10000);
    }

    function test_UpdateTakerFee_RevertTooHigh() public {
        vm.expectRevert(NFTExchange__InvalidTakerFee.selector);
        testableExchange.updateTakerFee(10001); // Over 100%
    }

    function test_UpdateMarketplaceWallet_SameAddress() public {
        address currentWallet = testableExchange.marketplaceWallet();

        // Setting to same address should work
        testableExchange.updateMarketplaceWallet(currentWallet);

        assertEq(testableExchange.marketplaceWallet(), currentWallet);
    }

    function test_UpdateMarketplaceWallet_RevertZeroAddress() public {
        vm.expectRevert(NFTExchange__InvalidMarketplaceWallet.selector);
        testableExchange.updateMarketplaceWallet(address(0));
    }

    function test_UpdateMarketplaceWallet_RevertNotOwner() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), nonOwner));
        testableExchange.updateMarketplaceWallet(makeAddr("newWallet"));
    }

    function test_UpdateTakerFee_RevertNotOwner() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), nonOwner));
        testableExchange.updateTakerFee(500);
    }

    // ============================================================================
    // CONSTRUCTOR TESTS
    // ============================================================================

    function test_Constructor_Success() public {
        assertEq(testableExchange.marketplaceWallet(), MARKETPLACE_WALLET);
        assertEq(testableExchange.getTakerFee(), 200); // Default 2%
    }

    function test_Constructor_RevertZeroAddress() public {
        CoverageTestableBaseNFTExchange testExchange = new CoverageTestableBaseNFTExchange();
        vm.expectRevert(NFTExchange__InvalidMarketplaceWallet.selector);
        testExchange.initialize(address(0), address(this));
    }

    // ============================================================================
    // VIEW FUNCTION TESTS
    // ============================================================================

    function test_GetFloorPrice() public {
        uint256 floorPrice = testableExchange.getFloorPrice(address(mockERC721));
        assertEq(floorPrice, 1 ether); // Default implementation returns 1 ETH
    }

    function test_GetTopTraitPrice() public {
        uint256 topTraitPrice = testableExchange.getTopTraitPrice(address(mockERC721), 1);
        uint256 expectedPrice = (1 ether * 120) / 100; // 20% above floor
        assertEq(topTraitPrice, expectedPrice);
    }

    function test_GetLadderPrice() public {
        uint256 ladderPrice = testableExchange.getLadderPrice(address(mockERC721), 1);
        uint256 expectedPrice = (1 ether * 110) / 100; // 10% above floor
        assertEq(ladderPrice, expectedPrice);
    }

    function test_Get24hVolume() public {
        uint256 volume = testableExchange.get24hVolume(address(mockERC721));
        assertEq(volume, 10 ether); // Default implementation returns 10 ETH
    }

    function test_GetRoyaltyInfo_WithMockContract() public {
        (address receiver, uint256 royaltyAmount) = testableExchange.getRoyaltyInfo(address(mockERC721), 1, 1 ether);

        // MockERC721 has ERC2981 (5% to test contract) which takes precedence over fee contract
        assertEq(receiver, address(this)); // ERC2981 returns test contract
        assertEq(royaltyAmount, 0.05 ether); // 5% of 1 ether
    }

    // ============================================================================
    // LISTING ARRAY FUNCTIONS TESTS
    // ============================================================================

    function test_GetListingsByCollection_EmptyArray() public {
        bytes32[] memory listings = testableExchange.getListingsByCollection(address(mockERC721));
        assertEq(listings.length, 0);
    }

    function test_GetListingsBySeller_EmptyArray() public {
        bytes32[] memory listings = testableExchange.getListingsBySeller(SELLER);
        assertEq(listings.length, 0);
    }

    function test_GetGeneratedListingId() public {
        bytes32 listingId = testableExchange.getGeneratedListingId(address(mockERC721), 1, SELLER);

        // Should generate a non-zero listing ID
        assertTrue(listingId != bytes32(0));
    }

    // ============================================================================
    // INTERFACE IMPLEMENTATION TESTS
    // ============================================================================

    function test_Version() public {
        string memory version = testableExchange.version();
        assertEq(version, "1.0.0");
    }

    function test_ContractType() public {
        string memory contractType = testableExchange.contractType();
        assertEq(contractType, "ERC721NFTExchange");
    }

    function test_IsActive() public {
        assertTrue(testableExchange.isActive());
    }

    function test_SupportedStandard() public {
        string memory standard = testableExchange.supportedStandard();
        assertEq(standard, "TEST"); // Test implementation returns TEST
    }

    function test_SupportsInterface() public {
        // Test ERC165 interface support
        assertTrue(testableExchange.supportsInterface(0x01ffc9a7)); // ERC165

        // Test unsupported interface
        assertFalse(testableExchange.supportsInterface(0x12345678));
    }
}

/**
 * @title CoverageTestableBaseNFTExchange
 * @notice Test contract that exposes BaseNFTExchange functions for coverage testing
 */
contract CoverageTestableBaseNFTExchange is BaseNFTExchange {
    function initialize(address _marketplaceWallet, address _owner) external initializer {
        __BaseNFTExchange_init(_marketplaceWallet, _owner);
    }

    // Override supportedStandard to return a specific value for testing
    function supportedStandard() public pure override returns (string memory) {
        return "TEST";
    }
}
