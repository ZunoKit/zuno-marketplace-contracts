// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {ERC721NFTExchange} from "src/core/exchange/ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "src/core/exchange/ERC1155NFTExchange.sol";
import {ERC721CollectionFactory} from "src/core/factory/ERC721CollectionFactory.sol";
import {ERC1155CollectionFactory} from "src/core/factory/ERC1155CollectionFactory.sol";

contract DeployAll is Script {
    struct AllContracts {
        // Exchange contracts
        address erc721Exchange;
        address erc1155Exchange;
        // Collection factory contracts
        address erc721CollectionFactory;
        address erc1155CollectionFactory;
    }

    function run() external {
        address marketplaceWallet = vm.envOr("MARKETPLACE_WALLET", msg.sender);

        // Validate marketplace wallet
        if (marketplaceWallet == address(0)) {
            revert("NFTExchange__InvalidMarketplaceWallet()");
        }

        console2.log("=== Deploying All Contracts ===");
        console2.log("Marketplace wallet:", marketplaceWallet);
        console2.log("Deployer:", msg.sender);

        vm.startBroadcast();
        AllContracts memory contracts = _deployAllContracts(marketplaceWallet);
        vm.stopBroadcast();

        _saveAddressesAndSummary(marketplaceWallet, contracts);
    }

    function _deployAllContracts(address marketplaceWallet) internal returns (AllContracts memory contracts) {
        console2.log("\n1. Deploying Exchange Contracts...");

        // Deploy ERC721 Exchange
        ERC721NFTExchange erc721Ex = new ERC721NFTExchange();
        erc721Ex.initialize(marketplaceWallet, msg.sender);
        contracts.erc721Exchange = address(erc721Ex);
        console2.log("   ERC721NFTExchange:", contracts.erc721Exchange);

        // Deploy ERC1155 Exchange
        ERC1155NFTExchange erc1155Ex = new ERC1155NFTExchange();
        erc1155Ex.initialize(marketplaceWallet, msg.sender);
        contracts.erc1155Exchange = address(erc1155Ex);
        console2.log("   ERC1155NFTExchange:", contracts.erc1155Exchange);

        console2.log("\n2. Deploying Collection Factory Contracts...");

        // Deploy ERC721 Collection Factory
        ERC721CollectionFactory erc721Factory = new ERC721CollectionFactory();
        contracts.erc721CollectionFactory = address(erc721Factory);
        console2.log("   ERC721CollectionFactory:", contracts.erc721CollectionFactory);

        // Deploy ERC1155 Collection Factory
        ERC1155CollectionFactory erc1155Factory = new ERC1155CollectionFactory();
        contracts.erc1155CollectionFactory = address(erc1155Factory);
        console2.log("   ERC1155CollectionFactory:", contracts.erc1155CollectionFactory);
    }

    function _saveAddressesAndSummary(address marketplaceWallet, AllContracts memory contracts) internal {
        console2.log("\n=== Deployment Summary ===");
        console2.log("Exchange Contracts:");
        console2.log("  ERC721 Exchange:", contracts.erc721Exchange);
        console2.log("  ERC1155 Exchange:", contracts.erc1155Exchange);
        console2.log("\nCollection Factory Contracts:");
        console2.log("  ERC721 Collection Factory:", contracts.erc721CollectionFactory);
        console2.log("  ERC1155 Collection Factory:", contracts.erc1155CollectionFactory);
        console2.log("\nMarketplace Wallet:", marketplaceWallet);
        console2.log("\nDeployment completed successfully!");
    }
}
