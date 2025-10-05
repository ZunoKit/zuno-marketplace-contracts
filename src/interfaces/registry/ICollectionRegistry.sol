// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ICollectionRegistry
 * @notice Interface for managing collection factories and verification
 * @dev Provides unified access to collection creation across different token standards
 */
interface ICollectionRegistry {
    /**
     * @notice Emitted when a new factory is registered
     * @param tokenType The token type identifier
     * @param factory The factory contract address
     */
    event FactoryRegistered(string indexed tokenType, address indexed factory);

    /**
     * @notice Emitted when a factory is updated
     * @param tokenType The token type identifier
     * @param oldFactory The old factory address
     * @param newFactory The new factory address
     */
    event FactoryUpdated(string indexed tokenType, address oldFactory, address newFactory);

    /**
     * @notice Emitted when a collection is verified
     * @param collection The collection address
     * @param tokenType The token type
     */
    event CollectionVerified(address indexed collection, string tokenType);

    /**
     * @notice Get the factory contract for a specific token type
     * @param tokenType The token type (e.g., "ERC721", "ERC1155")
     * @return The factory contract address
     */
    function getFactory(string memory tokenType) external view returns (address);

    /**
     * @notice Register a new factory contract
     * @param tokenType The token type identifier
     * @param factory The factory contract address
     */
    function registerFactory(string memory tokenType, address factory) external;

    /**
     * @notice Update an existing factory contract
     * @param tokenType The token type identifier
     * @param newFactory The new factory contract address
     */
    function updateFactory(string memory tokenType, address newFactory) external;

    /**
     * @notice Verify that a collection was created by a registered factory
     * @param collection The collection address to verify
     * @return isValid True if the collection is valid
     * @return tokenType The token type of the collection
     */
    function verifyCollection(address collection) external view returns (bool isValid, string memory tokenType);

    /**
     * @notice Check if an address is a registered factory
     * @param factory The address to check
     * @return True if the address is a registered factory
     */
    function isRegisteredFactory(address factory) external view returns (bool);

    /**
     * @notice Get all registered factories
     * @return tokenTypes Array of token type identifiers
     * @return factories Array of factory addresses
     */
    function getAllFactories() external view returns (string[] memory tokenTypes, address[] memory factories);
}
