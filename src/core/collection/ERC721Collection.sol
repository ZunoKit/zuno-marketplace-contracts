// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {BaseCollection} from "src/common/BaseCollection.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {CollectionParams} from "src/types/ListingTypes.sol";
import {Minted, BatchMinted} from "src/events/CollectionEvents.sol";
import "src/errors/CollectionErrors.sol";

contract ERC721Collection is ERC721, BaseCollection, IERC2981 {
    constructor(CollectionParams memory params) ERC721(params.name, params.symbol) BaseCollection(params) {}

    function mint(address to) external payable {
        // checkMint now auto-updates stage internally
        uint256 requiredPayment = checkMint(to, 1);
        if (msg.value < requiredPayment) {
            revert Collection__InsufficientPayment();
        }
        s_tokenIdCounter++;
        _mintWithURI(to, s_tokenIdCounter);
    }

    function batchMintERC721(address to, uint256 amount) external payable {
        // checkMint now auto-updates stage internally
        uint256 requiredPayment = checkMint(to, amount);
        if (msg.value < requiredPayment) {
            revert Collection__InsufficientPayment();
        }
        _batchMint(to, amount);
    }

    function _batchMint(address to, uint256 amount) internal {
        uint256 startId = s_tokenIdCounter;
        s_tokenIdCounter += amount;

        for (uint256 i = 0; i < amount; i++) {
            _mintWithURI(to, startId + i + 1);
        }
        emit BatchMinted(to, amount);
    }

    function _mintWithURI(address to, uint256 tokenId) internal {
        s_mintedPerWallet[to]++;
        s_totalMinted++;
        _mint(to, tokenId);
        emit Minted(to, tokenId, 1);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string(abi.encodePacked(s_tokenURI, "/", Strings.toString(tokenId), ".json"));
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return s_feeContract.royaltyInfo(tokenId, salePrice);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
