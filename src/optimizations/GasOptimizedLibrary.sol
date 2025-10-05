// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title GasOptimizedLibrary
 * @notice Library containing gas-optimized utility functions
 * @dev Uses inline assembly for better gas efficiency
 */
library GasOptimizedLibrary {
    /**
     * @notice Gas-optimized keccak256 hash function
     * @param data The data to hash
     * @return hash The resulting hash
     */
    function efficientHash(
        bytes memory data
    ) internal pure returns (bytes32 hash) {
        assembly {
            hash := keccak256(add(data, 0x20), mload(data))
        }
    }

    /**
     * @notice Gas-optimized keccak256 hash for two addresses and a uint256
     * @param addr1 First address
     * @param addr2 Second address
     * @param value The uint256 value
     * @return hash The resulting hash
     */
    function hashAddressesAndValue(
        address addr1,
        address addr2,
        uint256 value
    ) internal pure returns (bytes32 hash) {
        assembly {
            let freeMemPtr := mload(0x40)
            mstore(freeMemPtr, addr1)
            mstore(add(freeMemPtr, 0x20), addr2)
            mstore(add(freeMemPtr, 0x40), value)
            hash := keccak256(freeMemPtr, 0x60)
        }
    }

    /**
     * @notice Gas-optimized hash for listing ID generation
     * @param contractAddr Contract address
     * @param tokenId Token ID
     * @param seller Seller address
     * @param timeValue Current timestamp value
     * @return hash The resulting hash
     */
    function generateOptimizedListingId(
        address contractAddr,
        uint256 tokenId,
        address seller,
        uint256 timeValue
    ) internal pure returns (bytes32 hash) {
        assembly {
            let freeMemPtr := mload(0x40)
            mstore(freeMemPtr, contractAddr)
            mstore(add(freeMemPtr, 0x20), tokenId)
            mstore(add(freeMemPtr, 0x40), seller)
            mstore(add(freeMemPtr, 0x60), timeValue)
            hash := keccak256(freeMemPtr, 0x80)
        }
    }

    /**
     * @notice Efficient ETH transfer with gas optimization
     * @param recipient Address to receive ETH
     * @param amount Amount to transfer
     * @return success Whether the transfer succeeded
     */
    function efficientTransfer(
        address recipient,
        uint256 amount
    ) internal returns (bool success) {
        assembly {
            success := call(gas(), recipient, amount, 0, 0, 0, 0)
        }
    }

    /**
     * @notice Packed struct for reducing storage slots
     */
    struct PackedListing {
        address seller; // 20 bytes
        uint96 price; // 12 bytes - fits in same slot
        uint64 startTime; // 8 bytes
        uint64 endTime; // 8 bytes
        uint32 status; // 4 bytes
        uint32 tokenId; // 4 bytes - if tokenId fits in uint32
    }

    /**
     * @notice Calculates fees using optimized math
     * @param amount Base amount
     * @param feeBps Fee in basis points
     * @return feeAmount The calculated fee
     */
    function calculateFeeOptimized(
        uint256 amount,
        uint256 feeBps
    ) internal pure returns (uint256 feeAmount) {
        assembly {
            // amount * feeBps / 10000
            feeAmount := div(mul(amount, feeBps), 10000)
        }
    }
}
