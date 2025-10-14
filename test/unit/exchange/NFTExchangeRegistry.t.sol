// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {NFTExchangeRegistry} from "src/core/exchange/NFTExchangeRegistry.sol";
import {ERC721NFTExchange} from "src/core/exchange/ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "src/core/exchange/ERC1155NFTExchange.sol";
import {ERC721NFTExchange} from "src/core/exchange/ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "src/core/exchange/ERC1155NFTExchange.sol";
import {NFTExchangeFactory} from "src/core/factory/NFTExchangeFactory.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC1155} from "test/mocks/MockERC1155.sol";
import "src/errors/NFTExchangeErrors.sol";

/**
 * @title NFTExchangeRegistryTest
 * @notice Test suite for NFTExchangeRegistry contract
 */
contract NFTExchangeRegistryTest is Test {
    NFTExchangeRegistry public registry;
    ERC721NFTExchange public erc721Exchange;
    ERC1155NFTExchange public erc1155Exchange;
    NFTExchangeFactory public factory;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    address public owner;
    address public user;
    address public marketplace;

    uint256 constant TOKEN_ID = 1;
    uint256 constant AMOUNT = 10;
    uint256 constant PRICE = 1 ether;
    uint256 constant DURATION = 7 days;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        marketplace = makeAddr("marketplace");

        vm.startPrank(owner);

        // Deploy factory and implementation contracts
        factory = new NFTExchangeFactory(marketplace);

        address erc721Impl = address(new ERC721NFTExchange());
        address erc1155Impl = address(new ERC1155NFTExchange());

        factory.setImplementation(NFTExchangeFactory.ExchangeType.ERC721, erc721Impl);
        factory.setImplementation(NFTExchangeFactory.ExchangeType.ERC1155, erc1155Impl);

        // Create exchange contracts
        address erc721ExchangeAddr = factory.createExchange(NFTExchangeFactory.ExchangeType.ERC721);
        address erc1155ExchangeAddr = factory.createExchange(NFTExchangeFactory.ExchangeType.ERC1155);

        erc721Exchange = ERC721NFTExchange(erc721ExchangeAddr);
        erc1155Exchange = ERC1155NFTExchange(erc1155ExchangeAddr);

        // Deploy registry
        registry = new NFTExchangeRegistry(address(factory));

        // Deploy test tokens
        mockERC721 = new MockERC721("Test ERC721", "T721");
        mockERC1155 = new MockERC1155("Test ERC1155", "T1155");

        vm.stopPrank();

        // Mint tokens to user
        vm.startPrank(user);
        mockERC721.mint(user, TOKEN_ID);
        mockERC1155.mint(user, TOKEN_ID, AMOUNT);
        vm.stopPrank();
    }

    // ============================================================================
    // CONSTRUCTOR TESTS
    // ============================================================================

    function test_Constructor_Success() public {
        assertEq(address(registry.erc721Exchange()), address(erc721Exchange));
        assertEq(address(registry.erc1155Exchange()), address(erc1155Exchange));
    }

    function test_GetExchangeAddresses() public {
        (address erc721Addr, address erc1155Addr) = registry.getExchangeAddresses();
        assertEq(erc721Addr, address(erc721Exchange));
        assertEq(erc1155Addr, address(erc1155Exchange));
    }

    // ============================================================================
    // UNIFIED LISTING TESTS
    // ============================================================================

    function test_ListERC721NFT_Success() public {
        vm.startPrank(user);

        // Approve registry to transfer NFT
        mockERC721.setApprovalForAll(address(registry), true);

        // List NFT through registry (unified interface)
        registry.listNFT(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION);

        // Verify total listings increased
        assertEq(registry.getTotalListings(), 1);

        vm.stopPrank();
    }

    function test_ListERC1155NFT_Success() public {
        vm.startPrank(user);

        // Approve registry to transfer NFT
        mockERC1155.setApprovalForAll(address(registry), true);

        // List NFT through registry (unified interface)
        registry.listNFT(address(mockERC1155), TOKEN_ID, AMOUNT, PRICE, DURATION);

        // Verify total listings increased
        assertEq(registry.getTotalListings(), 1);

        vm.stopPrank();
    }

    function test_ListERC721NFT_InvalidAmount_Reverts() public {
        vm.startPrank(user);
        mockERC721.setApprovalForAll(address(registry), true);

        vm.expectRevert("ERC721 amount must be 1");
        registry.listNFT(address(mockERC721), TOKEN_ID, 2, PRICE, DURATION);

        vm.stopPrank();
    }

    function test_ListERC1155NFT_ZeroAmount_Reverts() public {
        vm.startPrank(user);
        mockERC1155.setApprovalForAll(address(registry), true);

        vm.expectRevert("ERC1155 amount must be > 0");
        registry.listNFT(address(mockERC1155), TOKEN_ID, 0, PRICE, DURATION);

        vm.stopPrank();
    }

    function test_ListUnsupportedNFT_Reverts() public {
        address unsupportedContract = makeAddr("unsupported");

        vm.expectRevert(); // Will revert without data for unsupported contract
        registry.listNFT(unsupportedContract, TOKEN_ID, 1, PRICE, DURATION);
    }

    // ============================================================================
    // CANCEL AND BUY TESTS
    // ============================================================================

    function test_CancelListing_Success() public {
        vm.startPrank(user);

        // List NFT first
        mockERC721.setApprovalForAll(address(registry), true);
        registry.listNFT(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION);

        // Get listing ID - Registry is now the seller on exchange
        bytes32 listingId = erc721Exchange.getGeneratedListingId(address(mockERC721), TOKEN_ID, address(registry));

        // Cancel through registry
        registry.cancelListing(listingId);

        // Verify total listings decreased
        assertEq(registry.getTotalListings(), 0);

        vm.stopPrank();
    }

    // ============================================================================
    // EVENT TESTS
    // ============================================================================

    function test_ListingRouted_Event() public {
        vm.startPrank(user);
        mockERC721.setApprovalForAll(address(registry), true);

        bytes32 expectedListingId =
            erc721Exchange.getGeneratedListingId(address(mockERC721), TOKEN_ID, address(registry));

        vm.expectEmit(true, true, false, true);
        emit ListingRouted(expectedListingId, address(erc721Exchange), "ERC721");

        registry.listNFT(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION);

        vm.stopPrank();
    }

    // ============================================================================
    // VIEW FUNCTION TESTS
    // ============================================================================

    function test_GetExchangeForNFT_ERC721() public view {
        address exchange = registry.getExchangeForNFT(address(mockERC721));
        assertEq(exchange, address(erc721Exchange));
    }

    function test_GetExchangeForNFT_ERC1155() public view {
        address exchange = registry.getExchangeForNFT(address(mockERC1155));
        assertEq(exchange, address(erc1155Exchange));
    }

    function test_GetExchangeForNFT_Unsupported_Reverts() public {
        address unsupportedContract = makeAddr("unsupported");

        vm.expectRevert(); // Will revert without data for unsupported contract
        registry.getExchangeForNFT(unsupportedContract);
    }

    function test_GetTotalListings_InitiallyZero() public view {
        assertEq(registry.getTotalListings(), 0);
    }

    function test_GetTotalListings_AfterListing() public {
        vm.startPrank(user);
        mockERC721.setApprovalForAll(address(registry), true);

        registry.listNFT(address(mockERC721), TOKEN_ID, 1, PRICE, DURATION);

        assertEq(registry.getTotalListings(), 1);
        vm.stopPrank();
    }

    // ============================================================================
    // INTERFACE TESTS
    // ============================================================================

    function test_ContractType() public view {
        assertEq(registry.contractType(), "NFTExchangeRegistry");
    }

    function test_Version() public view {
        assertEq(registry.version(), "1.0.0");
    }

    function test_IsActive() public view {
        assertTrue(registry.isActive());
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    event ListingRouted(bytes32 indexed listingId, address indexed exchange, string nftType);
}
