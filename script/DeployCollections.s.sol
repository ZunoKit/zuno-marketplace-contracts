// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {ERC721CollectionFactory} from "src/core/collection/ERC721CollectionFactory.sol";
import {ERC1155CollectionFactory} from "src/core/collection/ERC1155CollectionFactory.sol";

contract DeployCollections is Script {
    struct CollectionsContracts {
        ERC721CollectionFactory erc721CollectionFactory;
        ERC1155CollectionFactory erc1155CollectionFactory;
    }

    function run() external {
        console2.log("=== Deploying Collection Factories ===");
        console2.log("Deployer:", msg.sender);

        vm.startBroadcast();

        CollectionsContracts memory c;

        // Deploy ERC721 Collection Factory
        c.erc721CollectionFactory = new ERC721CollectionFactory();
        console2.log("ERC721CollectionFactory:", address(c.erc721CollectionFactory));

        // Deploy ERC1155 Collection Factory
        c.erc1155CollectionFactory = new ERC1155CollectionFactory();
        console2.log("ERC1155CollectionFactory:", address(c.erc1155CollectionFactory));

        vm.stopBroadcast();

        // Summary
        console2.log("=== Summary ===");
        console2.log("ERC721CollectionFactory:", address(c.erc721CollectionFactory));
        console2.log("ERC1155CollectionFactory:", address(c.erc1155CollectionFactory));
    }
}
