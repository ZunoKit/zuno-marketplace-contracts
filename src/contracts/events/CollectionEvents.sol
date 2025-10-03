// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {MintStage} from "src/contracts/types/ListingTypes.sol";

event Minted(address indexed to, uint256 indexed tokenId, uint256 amount);

event BatchMinted(address indexed to, uint256 amount);

event StageUpdated(MintStage stage, uint256 timestamp);

event ERC721CollectionCreated(address indexed collectionAddress, address indexed creator);

event ERC1155CollectionCreated(address indexed collectionAddress, address indexed creator);
