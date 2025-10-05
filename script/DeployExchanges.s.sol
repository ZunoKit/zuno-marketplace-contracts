// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {ERC721NFTExchange} from "src/core/NFTExchange/ERC721NFTExchange.sol";
import {ERC1155NFTExchange} from "src/core/NFTExchange/ERC1155NFTExchange.sol";

contract DeployExchanges is Script {
    struct CoreContracts {
        address erc721Exchange;
        address erc1155Exchange;
    }

    function run() external {
        address marketplaceWallet = vm.envOr("MARKETPLACE_WALLET", msg.sender);
        console2.log("=== Deploying Exchanges ===");
        console2.log("Marketplace wallet:", marketplaceWallet);
        console2.log("Deployer:", msg.sender);

        vm.startBroadcast();
        CoreContracts memory core = _deployCoreContracts(marketplaceWallet);
        vm.stopBroadcast();

        _saveAddressesAndSummary(marketplaceWallet, core);
    }

    function _deployCoreContracts(address marketplaceWallet) internal returns (CoreContracts memory core) {
        console2.log("\n1. Deploying Exchanges (direct)...");
        ERC721NFTExchange erc721Ex = new ERC721NFTExchange();
        erc721Ex.initialize(marketplaceWallet, msg.sender);
        core.erc721Exchange = address(erc721Ex);
        console2.log("   ERC721NFTExchange:", core.erc721Exchange);

        ERC1155NFTExchange erc1155Ex = new ERC1155NFTExchange();
        erc1155Ex.initialize(marketplaceWallet, msg.sender);
        core.erc1155Exchange = address(erc1155Ex);
        console2.log("   ERC1155NFTExchange:", core.erc1155Exchange);
    }

    function _saveAddressesAndSummary(address marketplaceWallet, CoreContracts memory core) internal {
        console2.log("\n22. Saving contract addresses...");
        string memory json = "deployment-exchanges";
        vm.serializeAddress(json, "erc721Exchange", core.erc721Exchange);
        vm.serializeAddress(json, "erc1155Exchange", core.erc1155Exchange);
        string memory finalJson = vm.serializeAddress(json, "marketplaceWallet", marketplaceWallet);

        console2.log("\n=== Summary ===");
        console2.log("ERC721 Exchange:", core.erc721Exchange);
        console2.log("ERC1155 Exchange:", core.erc1155Exchange);
        console2.log("MarketplaceWallet:", marketplaceWallet);
    }
}
