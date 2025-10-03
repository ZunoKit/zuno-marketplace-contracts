// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC721CollectionFactory} from "src/contracts/core/collection/ERC721CollectionFactory.sol";
import {ERC1155CollectionFactory} from "src/contracts/core/collection/ERC1155CollectionFactory.sol";
import {CollectionFactoryRegistry} from "src/contracts/core/collection/CollectionFactoryRegistry.sol";
import {CollectionParams} from "src/contracts/types/ListingTypes.sol";
import {ERC721CollectionCreated, ERC1155CollectionCreated} from "src/contracts/events/CollectionEvents.sol";
import {ICollectionFactory} from "src/contracts/interfaces/IMarketplaceCore.sol";

contract UnitCollectionFactoryRegistryTest is Test {
    struct TestSetup {
        ERC721CollectionFactory erc721Factory;
        ERC1155CollectionFactory erc1155Factory;
        CollectionFactoryRegistry registry;
        CollectionParams params;
        address owner;
    }

    TestSetup private setup;

    function setUp() public {
        setup.owner = makeAddr("owner");

        // Deploy individual factories
        setup.erc721Factory = new ERC721CollectionFactory();
        setup.erc1155Factory = new ERC1155CollectionFactory();

        // Deploy registry
        setup.registry = new CollectionFactoryRegistry(address(setup.erc721Factory), address(setup.erc1155Factory));

        setup.params = CollectionParams({
            owner: setup.owner,
            name: "Test Collection",
            symbol: "TEST",
            description: "Test Description",
            tokenURI: "ipfs://test",
            mintPrice: 0.1 ether,
            maxSupply: 1000,
            mintLimitPerWallet: 5,
            mintStartTime: block.timestamp + 1 days,
            allowlistMintPrice: 0.08 ether,
            publicMintPrice: 0.1 ether,
            allowlistStageDuration: 1 days,
            royaltyFee: 250 // 2.5%
        });
    }

    function test_CreateERC721Collection() public {
        // Expect the event to be emitted
        vm.expectEmit(false, true, false, false);
        emit ERC721CollectionCreated(address(0), address(this));

        address collectionAddr = setup.registry.createERC721Collection(setup.params);

        // Verify collection was created
        assertTrue(collectionAddr != address(0));
        assertTrue(setup.registry.isValidCollection(collectionAddr));
        assertEq(setup.registry.getTotalCollections(), 1);
    }

    function test_CreateERC1155Collection() public {
        // Expect the event to be emitted
        vm.expectEmit(false, true, false, false);
        emit ERC1155CollectionCreated(address(0), address(this));

        address collectionAddr = setup.registry.createERC1155Collection(setup.params);

        // Verify collection was created
        assertTrue(collectionAddr != address(0));
        assertTrue(setup.registry.isValidCollection(collectionAddr));
        assertEq(setup.registry.getTotalCollections(), 1);
    }

    function test_MixedCollectionCreation() public {
        // Create ERC721 collection
        address erc721Collection = setup.registry.createERC721Collection(setup.params);

        // Create ERC1155 collection
        setup.params.name = "ERC1155 Collection";
        setup.params.symbol = "TEST1155";
        address erc1155Collection = setup.registry.createERC1155Collection(setup.params);

        // Verify both collections
        assertTrue(setup.registry.isValidCollection(erc721Collection));
        assertTrue(setup.registry.isValidCollection(erc1155Collection));
        assertEq(setup.registry.getTotalCollections(), 2);
        assertTrue(erc721Collection != erc1155Collection);
    }

    function test_GetFactoryAddresses() public view {
        (address erc721FactoryAddr, address erc1155FactoryAddr) = setup.registry.getFactoryAddresses();

        assertEq(erc721FactoryAddr, address(setup.erc721Factory));
        assertEq(erc1155FactoryAddr, address(setup.erc1155Factory));
    }

    function test_GetFactoryCollectionCounts() public {
        // Create collections through registry
        setup.registry.createERC721Collection(setup.params);
        setup.params.name = "Second ERC721";
        setup.registry.createERC721Collection(setup.params);

        setup.params.name = "ERC1155 Collection";
        setup.registry.createERC1155Collection(setup.params);

        (uint256 erc721Count, uint256 erc1155Count) = setup.registry.getFactoryCollectionCounts();

        assertEq(erc721Count, 2);
        assertEq(erc1155Count, 1);
    }

    function test_GetSupportedStandards() public view {
        string[] memory standards = setup.registry.getSupportedStandards();
        assertEq(standards.length, 2);
        assertEq(standards[0], "ERC721");
        assertEq(standards[1], "ERC1155");
    }

    function test_ContractType() public view {
        assertEq(setup.registry.contractType(), "CollectionFactoryRegistry");
    }

    function test_Version() public view {
        assertEq(setup.registry.version(), "1.0.0");
    }

    function test_IsActive() public view {
        assertTrue(setup.registry.isActive());
    }

    function test_SupportsInterface() public view {
        // Should support ICollectionFactory interface
        assertTrue(setup.registry.supportsInterface(type(ICollectionFactory).interfaceId));

        // Should support ERC165 interface
        assertTrue(setup.registry.supportsInterface(0x01ffc9a7));
    }

    function test_IsValidCollectionFallback() public {
        // Create collection directly through individual factory
        address directCollection = setup.erc721Factory.createERC721Collection(setup.params);

        // Registry should still recognize it through fallback
        assertTrue(setup.registry.isValidCollection(directCollection));
    }

    function test_InvalidCollectionAddress() public {
        address randomAddr = makeAddr("random");
        assertFalse(setup.registry.isValidCollection(randomAddr));
    }

    function test_EmptyCollectionCount() public view {
        assertEq(setup.registry.getTotalCollections(), 0);
    }

    function test_FactoriesSetEvent() public {
        // Test that the event is emitted during construction
        vm.expectEmit(true, true, false, false);
        emit CollectionFactoryRegistry.FactoriesSet(address(setup.erc721Factory), address(setup.erc1155Factory));

        new CollectionFactoryRegistry(address(setup.erc721Factory), address(setup.erc1155Factory));
    }
}
