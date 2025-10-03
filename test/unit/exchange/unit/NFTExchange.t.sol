// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {NFTExchangeFactory} from "src/contracts/core/NFTExchange/NFTExchangeFactory.sol";
import {ERC721NFTExchange} from "src/contracts/core/NFTExchange/ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "src/contracts/core/NFTExchange/ERC1155NFTExchange.sol";
import {ERC721NFTExchange} from "src/contracts/core/NFTExchange/ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "src/contracts/core/NFTExchange/ERC1155NFTExchange.sol";
import "src/contracts/errors/NFTExchangeErrors.sol";

contract NFTExchangeTest is Test {
    NFTExchangeFactory public exchange;
    address public marketplace;
    address public owner;
    address public user;
    address public erc721Impl;
    address public erc1155Impl;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        marketplace = makeAddr("marketplace");

        vm.startPrank(owner);
        exchange = new NFTExchangeFactory(marketplace);

        // Deploy implementation contracts
        erc721Impl = address(new ERC721NFTExchange());
        erc1155Impl = address(new ERC1155NFTExchange());

        // Set implementations
        exchange.setImplementation(NFTExchangeFactory.ExchangeType.ERC721, erc721Impl);
        exchange.setImplementation(NFTExchangeFactory.ExchangeType.ERC1155, erc1155Impl);
        vm.stopPrank();
    }

    function test_Constructor() public {
        vm.startPrank(owner);
        NFTExchangeFactory newExchange = new NFTExchangeFactory(marketplace);
        assertEq(newExchange.marketplaceWallet(), marketplace);
        vm.stopPrank();
    }

    function test_CreateExchange() public {
        vm.startPrank(owner);
        address erc721Exchange = exchange.createExchange(NFTExchangeFactory.ExchangeType.ERC721);
        address erc1155Exchange = exchange.createExchange(NFTExchangeFactory.ExchangeType.ERC1155);

        assertTrue(exchange.isValidExchange(erc721Exchange));
        assertTrue(exchange.isValidExchange(erc1155Exchange));
        assertEq(uint256(exchange.getExchangeType(erc721Exchange)), uint256(NFTExchangeFactory.ExchangeType.ERC721));
        assertEq(uint256(exchange.getExchangeType(erc1155Exchange)), uint256(NFTExchangeFactory.ExchangeType.ERC1155));
        vm.stopPrank();
    }

    function test_RemoveExchange() public {
        vm.startPrank(owner);
        address erc721Exchange = exchange.createExchange(NFTExchangeFactory.ExchangeType.ERC721);
        exchange.removeExchange(erc721Exchange);
        assertFalse(exchange.isValidExchange(erc721Exchange));
        vm.stopPrank();
    }

    function test_UpdateMarketplaceWallet() public {
        vm.startPrank(owner);
        address newMarketplace = makeAddr("newMarketplace");
        exchange.updateMarketplaceWallet(newMarketplace);
        assertEq(exchange.marketplaceWallet(), newMarketplace);
        vm.stopPrank();
    }

    function test_RevertWhen_CreateExchangeAsNonOwner() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user));
        exchange.createExchange(NFTExchangeFactory.ExchangeType.ERC721);
        vm.stopPrank();
    }

    function test_RevertWhen_CreateExchangeWithZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(NFTExchange__InvalidMarketplaceWallet.selector);
        NFTExchangeFactory newExchange = new NFTExchangeFactory(address(0));
        vm.stopPrank();
    }

    function test_RevertWhen_CreateExchangeWithoutImplementation() public {
        vm.startPrank(owner);
        NFTExchangeFactory newExchange = new NFTExchangeFactory(marketplace);
        vm.expectRevert(NFTExchange__InvalidExchangeType.selector);
        newExchange.createExchange(NFTExchangeFactory.ExchangeType.ERC721);
        vm.stopPrank();
    }

    function test_RevertWhen_RemoveExchangeAsNonOwner() public {
        vm.startPrank(owner);
        address erc721Exchange = exchange.createExchange(NFTExchangeFactory.ExchangeType.ERC721);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user));
        exchange.removeExchange(erc721Exchange);
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateMarketplaceWalletAsNonOwner() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user));
        exchange.updateMarketplaceWallet(makeAddr("newMarketplace"));
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateMarketplaceWalletToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(NFTExchange__InvalidMarketplaceWallet.selector);
        exchange.updateMarketplaceWallet(address(0));
        vm.stopPrank();
    }
}
