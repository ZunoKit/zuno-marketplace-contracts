// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ArrayUtilsLib
 * @notice Library for common array operations used across marketplace contracts
 * @dev Centralizes array manipulation logic to reduce code duplication
 */
library ArrayUtilsLib {
    // ============================================================================
    // ERRORS
    // ============================================================================

    error ArrayUtils__ElementNotFound();
    error ArrayUtils__IndexOutOfBounds();
    error ArrayUtils__EmptyArray();

    // ============================================================================
    // BYTES32 ARRAY FUNCTIONS
    // ============================================================================

    /**
     * @notice Removes an element from a bytes32 array by value
     * @param array Storage reference to the array
     * @param element Element to remove
     * @return success True if element was found and removed
     */
    function removeBytes32Element(bytes32[] storage array, bytes32 element) internal returns (bool success) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                // Move last element to current position and pop
                array[i] = array[array.length - 1];
                array.pop();
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Removes an element from a bytes32 array by index
     * @param array Storage reference to the array
     * @param index Index to remove
     */
    function removeBytes32ElementByIndex(bytes32[] storage array, uint256 index) internal {
        if (index >= array.length) revert ArrayUtils__IndexOutOfBounds();

        // Move last element to current position and pop
        array[index] = array[array.length - 1];
        array.pop();
    }

    /**
     * @notice Finds the index of an element in a bytes32 array
     * @param array Array to search in
     * @param element Element to find
     * @return found True if element was found
     * @return index Index of the element (only valid if found is true)
     */
    function findBytes32Element(bytes32[] memory array, bytes32 element)
        internal
        pure
        returns (bool found, uint256 index)
    {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    /**
     * @notice Checks if a bytes32 array contains an element
     * @param array Array to search in
     * @param element Element to check for
     * @return contains True if array contains the element
     */
    function containsBytes32Element(bytes32[] memory array, bytes32 element) internal pure returns (bool contains) {
        (bool found,) = findBytes32Element(array, element);
        return found;
    }

    // ============================================================================
    // ADDRESS ARRAY FUNCTIONS
    // ============================================================================

    /**
     * @notice Removes an element from an address array by value
     * @param array Storage reference to the array
     * @param element Element to remove
     * @return success True if element was found and removed
     */
    function removeAddressElement(address[] storage array, address element) internal returns (bool success) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                // Move last element to current position and pop
                array[i] = array[array.length - 1];
                array.pop();
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Removes an element from an address array by index
     * @param array Storage reference to the array
     * @param index Index to remove
     */
    function removeAddressElementByIndex(address[] storage array, uint256 index) internal {
        if (index >= array.length) revert ArrayUtils__IndexOutOfBounds();

        // Move last element to current position and pop
        array[index] = array[array.length - 1];
        array.pop();
    }

    /**
     * @notice Finds the index of an element in an address array
     * @param array Array to search in
     * @param element Element to find
     * @return found True if element was found
     * @return index Index of the element (only valid if found is true)
     */
    function findAddressElement(address[] memory array, address element)
        internal
        pure
        returns (bool found, uint256 index)
    {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    /**
     * @notice Checks if an address array contains an element
     * @param array Array to search in
     * @param element Element to check for
     * @return contains True if array contains the element
     */
    function containsAddressElement(address[] memory array, address element) internal pure returns (bool contains) {
        (bool found,) = findAddressElement(array, element);
        return found;
    }

    // ============================================================================
    // UINT256 ARRAY FUNCTIONS
    // ============================================================================

    /**
     * @notice Removes an element from a uint256 array by value
     * @param array Storage reference to the array
     * @param element Element to remove
     * @return success True if element was found and removed
     */
    function removeUint256Element(uint256[] storage array, uint256 element) internal returns (bool success) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                // Move last element to current position and pop
                array[i] = array[array.length - 1];
                array.pop();
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Removes an element from a uint256 array by index
     * @param array Storage reference to the array
     * @param index Index to remove
     */
    function removeUint256ElementByIndex(uint256[] storage array, uint256 index) internal {
        if (index >= array.length) revert ArrayUtils__IndexOutOfBounds();

        // Move last element to current position and pop
        array[index] = array[array.length - 1];
        array.pop();
    }

    // ============================================================================
    // BATCH OPERATIONS
    // ============================================================================

    /**
     * @notice Removes multiple elements from a bytes32 array
     * @param array Storage reference to the array
     * @param elements Elements to remove
     * @return removedCount Number of elements successfully removed
     */
    function removeBatchBytes32Elements(bytes32[] storage array, bytes32[] memory elements)
        internal
        returns (uint256 removedCount)
    {
        for (uint256 i = 0; i < elements.length; i++) {
            if (removeBytes32Element(array, elements[i])) {
                removedCount++;
            }
        }
        return removedCount;
    }

    /**
     * @notice Removes multiple elements from an address array
     * @param array Storage reference to the array
     * @param elements Elements to remove
     * @return removedCount Number of elements successfully removed
     */
    function removeBatchAddressElements(address[] storage array, address[] memory elements)
        internal
        returns (uint256 removedCount)
    {
        for (uint256 i = 0; i < elements.length; i++) {
            if (removeAddressElement(array, elements[i])) {
                removedCount++;
            }
        }
        return removedCount;
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================

    /**
     * @notice Checks if an array is empty
     * @param array Array to check
     * @return isEmpty True if array is empty
     */
    function isEmptyBytes32Array(bytes32[] memory array) internal pure returns (bool isEmpty) {
        return array.length == 0;
    }

    /**
     * @notice Checks if an array is empty
     * @param array Array to check
     * @return isEmpty True if array is empty
     */
    function isEmptyAddressArray(address[] memory array) internal pure returns (bool isEmpty) {
        return array.length == 0;
    }

    /**
     * @notice Gets the last element of a bytes32 array
     * @param array Array to get last element from
     * @return lastElement The last element
     */
    function getLastBytes32Element(bytes32[] memory array) internal pure returns (bytes32 lastElement) {
        if (array.length == 0) revert ArrayUtils__EmptyArray();
        return array[array.length - 1];
    }

    /**
     * @notice Gets the last element of an address array
     * @param array Array to get last element from
     * @return lastElement The last element
     */
    function getLastAddressElement(address[] memory array) internal pure returns (address lastElement) {
        if (array.length == 0) revert ArrayUtils__EmptyArray();
        return array[array.length - 1];
    }
}
