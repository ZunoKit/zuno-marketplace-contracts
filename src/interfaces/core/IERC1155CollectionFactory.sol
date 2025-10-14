// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CollectionParams} from "src/types/ListingTypes.sol";

/**
 * @title IERC1155CollectionFactory
 * @notice Interface for ERC1155 Collection Factory
 */
interface IERC1155CollectionFactory {
    function createERC1155Collection(CollectionParams memory params) external returns (address);

    function isValidCollection(address collection) external view returns (bool);

    function totalCollections() external view returns (uint256);

    function getImplementation() external view returns (address);
}
