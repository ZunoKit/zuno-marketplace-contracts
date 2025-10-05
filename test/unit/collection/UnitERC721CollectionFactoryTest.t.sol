// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC721CollectionFactory} from "src/core/factory/ERC721CollectionFactory.sol";
import {CollectionParams} from "src/types/ListingTypes.sol";
import {ERC721CollectionCreated} from "src/events/CollectionEvents.sol";
import {ICollectionFactory} from "src/interfaces/IMarketplaceCore.sol";

contract UnitERC721CollectionFactoryTest is Test {
    struct TestSetup {
        ERC721CollectionFactory factory;
        CollectionParams params;
        address owner;
    }

    TestSetup private setup;

    function setUp() public {
        setup.owner = makeAddr("owner");
        setup.factory = new ERC721CollectionFactory();

        setup.params = CollectionParams({
            owner: setup.owner,
            name: "Test ERC721 Collection",
            symbol: "TEST721",
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

        address collectionAddr = setup.factory.createERC721Collection(setup.params);

        // Verify collection was created
        assertTrue(collectionAddr != address(0));
        assertTrue(setup.factory.isValidCollection(collectionAddr));
        assertEq(setup.factory.getTotalCollections(), 1);
    }

    function test_MultipleCollectionCreation() public {
        // Create first collection
        address collection1 = setup.factory.createERC721Collection(setup.params);

        // Create second collection with different params
        setup.params.name = "Second Collection";
        setup.params.symbol = "TEST2";
        address collection2 = setup.factory.createERC721Collection(setup.params);

        // Verify both collections
        assertTrue(setup.factory.isValidCollection(collection1));
        assertTrue(setup.factory.isValidCollection(collection2));
        assertEq(setup.factory.getTotalCollections(), 2);
        assertTrue(collection1 != collection2);
    }

    function test_GetSupportedStandards() public view {
        string[] memory standards = setup.factory.getSupportedStandards();
        assertEq(standards.length, 1);
        assertEq(standards[0], "ERC721");
    }

    function test_ContractType() public view {
        assertEq(setup.factory.contractType(), "ERC721CollectionFactory");
    }

    function test_Version() public view {
        assertEq(setup.factory.version(), "1.0.0");
    }

    function test_IsActive() public view {
        assertTrue(setup.factory.isActive());
    }

    function test_SupportsInterface() public view {
        // Should support ICollectionFactory interface
        assertTrue(setup.factory.supportsInterface(type(ICollectionFactory).interfaceId));

        // Should support ERC165 interface
        assertTrue(setup.factory.supportsInterface(0x01ffc9a7));
    }

    function test_InvalidCollectionAddress() public {
        address randomAddr = makeAddr("random");
        assertFalse(setup.factory.isValidCollection(randomAddr));
    }

    function test_EmptyCollectionCount() public view {
        assertEq(setup.factory.getTotalCollections(), 0);
    }
}
