// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CollectionParams} from "src/types/ListingTypes.sol";
import {ERC721CollectionCreated} from "src/events/CollectionEvents.sol";
import {ICollectionFactory} from "src/interfaces/IMarketplaceCore.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {ERC721CollectionImplementation} from "../proxy/ERC721CollectionImplementation.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title ERC721CollectionFactory
 * @notice Factory contract for creating ERC721 collections only
 * @dev Split from original CollectionFactory to reduce contract size
 */
contract ERC721CollectionFactory is ERC165, ICollectionFactory {
    // Implementation contract for minimal proxies
    address public immutable erc721CollectionImplementation;

    // Track created collections
    mapping(address => bool) private s_validCollections;
    uint256 private s_totalCollections;

    // Events
    event ImplementationDeployed(address indexed implementation);

    /**
     * @notice Constructor deploys the implementation contract
     */
    constructor() {
        erc721CollectionImplementation = address(new ERC721CollectionImplementation());
        emit ImplementationDeployed(erc721CollectionImplementation);
    }

    /**
     * @notice Creates a new ERC721 collection using proxy pattern
     * @param params Collection parameters
     * @return The address of the created collection
     */
    function createERC721Collection(CollectionParams memory params) external returns (address) {
        return _createCollectionInternal(params);
    }

    /**
     * @notice Internal function to create collection with proxy
     * @param params Collection parameters
     * @return collectionAddr Address of created collection
     */
    function _createCollectionInternal(CollectionParams memory params) internal returns (address collectionAddr) {
        // Validate parameters
        _validateCollectionParams(params);

        // Deploy proxy
        collectionAddr = _deployCollectionProxy();

        // Initialize proxy
        _initializeCollection(collectionAddr, params);

        // Register collection
        _registerCollection(collectionAddr);

        return collectionAddr;
    }

    /**
     * @notice Validates collection parameters
     * @param params Collection parameters to validate
     */
    function _validateCollectionParams(CollectionParams memory params) internal pure {
        require(params.owner != address(0), "Zero address owner");
        require(bytes(params.name).length > 0, "Empty name");
        require(bytes(params.symbol).length > 0, "Empty symbol");
        require(params.maxSupply > 0, "Zero max supply");
    }

    /**
     * @notice Deploys a new collection proxy
     * @return proxyAddress Address of deployed proxy
     */
    function _deployCollectionProxy() internal returns (address proxyAddress) {
        proxyAddress = Clones.clone(erc721CollectionImplementation);
    }

    /**
     * @notice Initializes the collection proxy
     * @param collectionAddr Address of the proxy
     * @param params Collection parameters
     */
    function _initializeCollection(address collectionAddr, CollectionParams memory params) internal {
        ERC721CollectionImplementation(collectionAddr).initialize(params);
    }

    /**
     * @notice Registers the collection in factory mappings
     * @param collectionAddr Address of the collection
     */
    function _registerCollection(address collectionAddr) internal {
        s_validCollections[collectionAddr] = true;
        s_totalCollections++;
        emit ERC721CollectionCreated(collectionAddr, msg.sender);
    }

    // ============ IMarketplaceCore Implementation ============

    function version() public pure override returns (string memory) {
        return "1.0.0";
    }

    function contractType() public pure override returns (string memory) {
        return "ERC721CollectionFactory";
    }

    function isActive() public pure override returns (bool) {
        return true;
    }

    // ============ ICollectionFactory Implementation ============

    function getTotalCollections() external view override returns (uint256) {
        return s_totalCollections;
    }

    function isValidCollection(address collection) external view override returns (bool) {
        return s_validCollections[collection];
    }

    function getSupportedStandards() external pure override returns (string[] memory) {
        string[] memory standards = new string[](1);
        standards[0] = "ERC721";
        return standards;
    }

    // ============ ERC165 Implementation ============

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ICollectionFactory).interfaceId || super.supportsInterface(interfaceId);
    }
}
