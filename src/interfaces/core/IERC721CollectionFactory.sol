// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CollectionParams} from "../../types/ListingTypes.sol";

/**
 * @title IERC721CollectionFactory
 * @notice Interface for ERC721 Collection Factory
 */
interface IERC721CollectionFactory {
    function createERC721Collection(CollectionParams memory params) external returns (address);

    function isValidCollection(address collection) external view returns (bool);

    function totalCollections() external view returns (uint256);

    function getImplementation() external view returns (address);
}
