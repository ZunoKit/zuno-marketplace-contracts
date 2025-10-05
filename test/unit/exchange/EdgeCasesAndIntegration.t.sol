// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {ERC721NFTExchange} from "src/core/exchange/ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "src/core/exchange/ERC1155NFTExchange.sol";
import {ERC721NFTExchange} from "src/core/exchange/ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "src/core/exchange/ERC1155NFTExchange.sol";
import {NFTExchangeFactory} from "src/core/factory/NFTExchangeFactory.sol";
import {MockERC721} from "test/mocks/MockERC721.sol";
import {MockERC1155} from "test/mocks/MockERC1155.sol";
import "src/errors/NFTExchangeErrors.sol";
import "src/events/NFTExchangeEvents.sol";

/**
 * @title EdgeCasesAndIntegrationTest
 * @notice Comprehensive test suite for edge cases and integration scenarios
 */
contract EdgeCasesAndIntegrationTest is Test {
    NFTExchangeFactory public nftExchangeFactory;
    ERC721NFTExchange public erc721Exchange;
    ERC1155NFTExchange public erc1155Exchange;
    MockERC721 public erc721Token;
    MockERC1155 public erc1155Token;
    address public owner;
    address public user;
    address public marketplace;
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant AMOUNT = 1;
    uint256 public constant PRICE = 1 ether;
    uint256 public constant DURATION = 1 days;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        marketplace = makeAddr("marketplace");

        vm.startPrank(owner);
        nftExchangeFactory = new NFTExchangeFactory(marketplace);

        // Deploy implementation contracts
        address erc721Impl = address(new ERC721NFTExchange());
        address erc1155Impl = address(new ERC1155NFTExchange());

        // Set implementations
        nftExchangeFactory.setImplementation(NFTExchangeFactory.ExchangeType.ERC721, erc721Impl);
        nftExchangeFactory.setImplementation(NFTExchangeFactory.ExchangeType.ERC1155, erc1155Impl);

        // Create exchanges
        address erc721ExchangeAddr = nftExchangeFactory.createExchange(NFTExchangeFactory.ExchangeType.ERC721);
        address erc1155ExchangeAddr = nftExchangeFactory.createExchange(NFTExchangeFactory.ExchangeType.ERC1155);

        erc721Exchange = ERC721NFTExchange(erc721ExchangeAddr);
        erc1155Exchange = ERC1155NFTExchange(erc1155ExchangeAddr);

        // Deploy test tokens
        erc721Token = new MockERC721("Test ERC721", "T721");
        erc1155Token = new MockERC1155("Test ERC1155", "");

        // Mint tokens to owner
        erc721Token.mint(owner, TOKEN_ID);
        erc1155Token.mint(owner, TOKEN_ID, AMOUNT, "");

        vm.stopPrank();
    }

    function test_ExchangeRegistration() public {
        assertTrue(nftExchangeFactory.isValidExchange(address(erc721Exchange)));
        assertTrue(nftExchangeFactory.isValidExchange(address(erc1155Exchange)));
    }

    function test_ExchangeType() public {
        assertEq(
            uint256(nftExchangeFactory.getExchangeType(address(erc721Exchange))),
            uint256(NFTExchangeFactory.ExchangeType.ERC721)
        );
        assertEq(
            uint256(nftExchangeFactory.getExchangeType(address(erc1155Exchange))),
            uint256(NFTExchangeFactory.ExchangeType.ERC1155)
        );
    }

    function test_MarketplaceWalletUpdate() public {
        vm.startPrank(owner);
        address newMarketplace = makeAddr("newMarketplace");
        nftExchangeFactory.updateMarketplaceWallet(newMarketplace);
        assertEq(nftExchangeFactory.marketplaceWallet(), newMarketplace);
        vm.stopPrank();
    }

    function test_ExchangeRemovalAndRecreation() public {
        // Create initial exchange
        vm.startPrank(owner);

        // First remove any existing exchange of this type
        address existingExchange = nftExchangeFactory.getExchangeByType(NFTExchangeFactory.ExchangeType.ERC721);
        if (existingExchange != address(0)) {
            nftExchangeFactory.removeExchange(existingExchange);
        }

        // Create new exchange
        address initialExchange = nftExchangeFactory.createExchange(NFTExchangeFactory.ExchangeType.ERC721);
        assertTrue(initialExchange != address(0), "Exchange should be created");
        assertTrue(nftExchangeFactory.isValidExchange(initialExchange), "Exchange should be valid");

        // Remove exchange
        nftExchangeFactory.removeExchange(initialExchange);
        assertFalse(nftExchangeFactory.isValidExchange(initialExchange), "Exchange should be removed");

        // Create new exchange
        address newExchange = nftExchangeFactory.createExchange(NFTExchangeFactory.ExchangeType.ERC721);
        assertTrue(newExchange != address(0), "New exchange should be created");
        assertTrue(nftExchangeFactory.isValidExchange(newExchange), "New exchange should be valid");
        assertTrue(newExchange != initialExchange, "New exchange should be different from old one");
        vm.stopPrank();
    }

    function test_ExchangeRemovalAndValidation() public {
        vm.startPrank(owner);
        nftExchangeFactory.removeExchange(address(erc721Exchange));
        assertFalse(nftExchangeFactory.isValidExchange(address(erc721Exchange)));
        assertTrue(nftExchangeFactory.isValidExchange(address(erc1155Exchange)));
        vm.stopPrank();
    }
}
