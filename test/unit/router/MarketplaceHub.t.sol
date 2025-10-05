// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {MarketplaceHub} from "src/router/MarketplaceHub.sol";
import {ExchangeRegistry} from "src/registry/ExchangeRegistry.sol";
import {CollectionRegistry} from "src/registry/CollectionRegistry.sol";
import {FeeRegistry} from "src/registry/FeeRegistry.sol";
import {AuctionRegistry} from "src/registry/AuctionRegistry.sol";
import {IExchangeRegistry} from "src/interfaces/registry/IExchangeRegistry.sol";
import {IAuctionRegistry} from "src/interfaces/registry/IAuctionRegistry.sol";
import {IFeeRegistry} from "src/interfaces/registry/IFeeRegistry.sol";

contract MarketplaceHubTest is Test {
    MarketplaceHub hub;
    ExchangeRegistry exchangeRegistry;
    CollectionRegistry collectionRegistry;
    FeeRegistry feeRegistry;
    AuctionRegistry auctionRegistry;

    address admin = makeAddr("admin");
    address erc721Exchange = makeAddr("erc721Exchange");
    address erc1155Exchange = makeAddr("erc1155Exchange");
    address erc721Factory = makeAddr("erc721Factory");
    address erc1155Factory = makeAddr("erc1155Factory");
    address englishAuction = makeAddr("englishAuction");
    address dutchAuction = makeAddr("dutchAuction");
    address auctionFactory = makeAddr("auctionFactory");
    address baseFee = makeAddr("baseFee");
    address feeManager = makeAddr("feeManager");
    address royaltyManager = makeAddr("royaltyManager");

    function setUp() public {
        vm.startPrank(admin);

        // Deploy registries
        exchangeRegistry = new ExchangeRegistry(admin);
        collectionRegistry = new CollectionRegistry(admin);
        feeRegistry = new FeeRegistry(admin, baseFee, feeManager, royaltyManager);
        auctionRegistry = new AuctionRegistry(admin);

        // Deploy hub
        hub = new MarketplaceHub(
            admin,
            address(exchangeRegistry),
            address(collectionRegistry),
            address(feeRegistry),
            address(auctionRegistry)
        );

        // Register some contracts
        exchangeRegistry.registerExchange(IExchangeRegistry.TokenStandard.ERC721, erc721Exchange);
        exchangeRegistry.registerExchange(IExchangeRegistry.TokenStandard.ERC1155, erc1155Exchange);
        collectionRegistry.registerFactory("ERC721", erc721Factory);
        collectionRegistry.registerFactory("ERC1155", erc1155Factory);
        auctionRegistry.registerAuction(IAuctionRegistry.AuctionType.ENGLISH, englishAuction);
        auctionRegistry.registerAuction(IAuctionRegistry.AuctionType.DUTCH, dutchAuction);
        auctionRegistry.updateAuctionFactory(auctionFactory);

        vm.stopPrank();
    }

    function test_GetAllAddresses() public {
        (
            address _erc721Exchange,
            address _erc1155Exchange,
            address _erc721Factory,
            address _erc1155Factory,
            address _englishAuction,
            address _dutchAuction,
            address _auctionFactory,
            address _feeRegistry
        ) = hub.getAllAddresses();

        assertEq(_erc721Exchange, erc721Exchange);
        assertEq(_erc1155Exchange, erc1155Exchange);
        assertEq(_erc721Factory, erc721Factory);
        assertEq(_erc1155Factory, erc1155Factory);
        assertEq(_englishAuction, englishAuction);
        assertEq(_dutchAuction, dutchAuction);
        assertEq(_auctionFactory, auctionFactory);
        assertEq(_feeRegistry, address(feeRegistry));
    }

    function test_GetERC721Exchange() public {
        address exchange = hub.getERC721Exchange();
        assertEq(exchange, erc721Exchange);
    }

    function test_GetERC1155Exchange() public {
        address exchange = hub.getERC1155Exchange();
        assertEq(exchange, erc1155Exchange);
    }

    function test_GetCollectionFactory() public {
        address factory = hub.getCollectionFactory("ERC721");
        assertEq(factory, erc721Factory);
    }

    function test_GetRegistryAddresses() public {
        assertEq(hub.getExchangeRegistry(), address(exchangeRegistry));
        assertEq(hub.getCollectionRegistry(), address(collectionRegistry));
        assertEq(hub.getFeeRegistry(), address(feeRegistry));
        assertEq(hub.getAuctionRegistry(), address(auctionRegistry));
    }

    function test_RevertIf_ZeroAddressInConstructor() public {
        vm.expectRevert(MarketplaceHub.MarketplaceHub__ZeroAddress.selector);
        new MarketplaceHub(admin, address(0), address(collectionRegistry), address(feeRegistry), address(auctionRegistry));
    }
}
