// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/contracts/libraries/ArrayUtilsLib.sol";

/**
 * @title ArrayStorageTest
 * @notice Test contract to expose storage arrays for testing
 */
contract ArrayStorageTest {
    bytes32[] public bytes32Array;
    address[] public addressArray;
    uint256[] public uint256Array;

    function addBytes32(bytes32 element) external {
        bytes32Array.push(element);
    }

    function removeBytes32Element(bytes32 element) external returns (bool) {
        return ArrayUtilsLib.removeBytes32Element(bytes32Array, element);
    }

    function removeBytes32AtIndex(uint256 index) external {
        ArrayUtilsLib.removeBytes32ElementByIndex(bytes32Array, index);
    }

    function findBytes32Index(bytes32 element) external view returns (bool found, uint256 index) {
        return ArrayUtilsLib.findBytes32Element(bytes32Array, element);
    }

    function containsBytes32(bytes32 element) external view returns (bool) {
        return ArrayUtilsLib.containsBytes32Element(bytes32Array, element);
    }

    function addAddress(address element) external {
        addressArray.push(element);
    }

    function removeAddressElement(address element) external returns (bool) {
        return ArrayUtilsLib.removeAddressElement(addressArray, element);
    }

    function removeAddressAtIndex(uint256 index) external {
        ArrayUtilsLib.removeAddressElementByIndex(addressArray, index);
    }

    function findAddressIndex(address element) external view returns (bool found, uint256 index) {
        return ArrayUtilsLib.findAddressElement(addressArray, element);
    }

    function containsAddress(address element) external view returns (bool) {
        return ArrayUtilsLib.containsAddressElement(addressArray, element);
    }

    function addUint256(uint256 element) external {
        uint256Array.push(element);
    }

    function removeUint256Element(uint256 element) external returns (bool) {
        return ArrayUtilsLib.removeUint256Element(uint256Array, element);
    }

    function removeUint256AtIndex(uint256 index) external {
        ArrayUtilsLib.removeUint256ElementByIndex(uint256Array, index);
    }

    function findUint256Index(uint256 element) external view returns (bool found, uint256 index) {
        // Note: ArrayUtilsLib doesn't have findUint256Element, so we implement it here
        for (uint256 i = 0; i < uint256Array.length; i++) {
            if (uint256Array[i] == element) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function containsUint256(uint256 element) external view returns (bool) {
        (bool found,) = this.findUint256Index(element);
        return found;
    }

    function getBytes32ArrayLength() external view returns (uint256) {
        return bytes32Array.length;
    }

    function getAddressArrayLength() external view returns (uint256) {
        return addressArray.length;
    }

    function getUint256ArrayLength() external view returns (uint256) {
        return uint256Array.length;
    }

    function getBytes32At(uint256 index) external view returns (bytes32) {
        return bytes32Array[index];
    }

    function getAddressAt(uint256 index) external view returns (address) {
        return addressArray[index];
    }

    function getUint256At(uint256 index) external view returns (uint256) {
        return uint256Array[index];
    }
}

/**
 * @title ArrayUtilsLibTest
 * @notice Comprehensive tests for ArrayUtilsLib library functions
 */
contract ArrayUtilsLibTest is Test {
    using ArrayUtilsLib for *;

    ArrayStorageTest public arrayStorage;

    bytes32 public constant ELEMENT1 = keccak256("element1");
    bytes32 public constant ELEMENT2 = keccak256("element2");
    bytes32 public constant ELEMENT3 = keccak256("element3");

    address public constant ADDR1 = address(0x1);
    address public constant ADDR2 = address(0x2);
    address public constant ADDR3 = address(0x3);

    function setUp() public {
        arrayStorage = new ArrayStorageTest();
    }

    // ============================================================================
    // BYTES32 ARRAY TESTS
    // ============================================================================

    function testRemoveBytes32Element_Success() public {
        // Add elements
        arrayStorage.addBytes32(ELEMENT1);
        arrayStorage.addBytes32(ELEMENT2);
        arrayStorage.addBytes32(ELEMENT3);

        assertEq(arrayStorage.getBytes32ArrayLength(), 3);

        // Remove middle element
        bool success = arrayStorage.removeBytes32Element(ELEMENT2);
        assertTrue(success);
        assertEq(arrayStorage.getBytes32ArrayLength(), 2);

        // Verify element is removed
        assertFalse(arrayStorage.containsBytes32(ELEMENT2));
        assertTrue(arrayStorage.containsBytes32(ELEMENT1));
        assertTrue(arrayStorage.containsBytes32(ELEMENT3));
    }

    function testRemoveBytes32Element_NotFound() public {
        arrayStorage.addBytes32(ELEMENT1);

        bool success = arrayStorage.removeBytes32Element(ELEMENT2);
        assertFalse(success);
        assertEq(arrayStorage.getBytes32ArrayLength(), 1);
    }

    function testRemoveBytes32AtIndex_Success() public {
        arrayStorage.addBytes32(ELEMENT1);
        arrayStorage.addBytes32(ELEMENT2);
        arrayStorage.addBytes32(ELEMENT3);

        // Remove at index 1 (ELEMENT2)
        arrayStorage.removeBytes32AtIndex(1);

        assertEq(arrayStorage.getBytes32ArrayLength(), 2);
        assertFalse(arrayStorage.containsBytes32(ELEMENT2));
    }

    function testRemoveBytes32AtIndex_IndexOutOfBounds() public {
        arrayStorage.addBytes32(ELEMENT1);

        vm.expectRevert(ArrayUtilsLib.ArrayUtils__IndexOutOfBounds.selector);
        arrayStorage.removeBytes32AtIndex(1);
    }

    function testFindBytes32Index_Found() public {
        arrayStorage.addBytes32(ELEMENT1);
        arrayStorage.addBytes32(ELEMENT2);
        arrayStorage.addBytes32(ELEMENT3);

        (bool found, uint256 index) = arrayStorage.findBytes32Index(ELEMENT2);
        assertTrue(found);
        assertEq(index, 1);
    }

    function testFindBytes32Index_NotFound() public {
        arrayStorage.addBytes32(ELEMENT1);

        (bool found, uint256 index) = arrayStorage.findBytes32Index(ELEMENT2);
        assertFalse(found);
        assertEq(index, 0);
    }

    function testContainsBytes32() public {
        arrayStorage.addBytes32(ELEMENT1);
        arrayStorage.addBytes32(ELEMENT2);

        assertTrue(arrayStorage.containsBytes32(ELEMENT1));
        assertTrue(arrayStorage.containsBytes32(ELEMENT2));
        assertFalse(arrayStorage.containsBytes32(ELEMENT3));
    }

    // ============================================================================
    // ADDRESS ARRAY TESTS
    // ============================================================================

    function testRemoveAddressElement_Success() public {
        arrayStorage.addAddress(ADDR1);
        arrayStorage.addAddress(ADDR2);
        arrayStorage.addAddress(ADDR3);

        assertEq(arrayStorage.getAddressArrayLength(), 3);

        bool success = arrayStorage.removeAddressElement(ADDR2);
        assertTrue(success);
        assertEq(arrayStorage.getAddressArrayLength(), 2);

        assertFalse(arrayStorage.containsAddress(ADDR2));
        assertTrue(arrayStorage.containsAddress(ADDR1));
        assertTrue(arrayStorage.containsAddress(ADDR3));
    }

    function testRemoveAddressElement_NotFound() public {
        arrayStorage.addAddress(ADDR1);

        bool success = arrayStorage.removeAddressElement(ADDR2);
        assertFalse(success);
        assertEq(arrayStorage.getAddressArrayLength(), 1);
    }

    function testRemoveAddressAtIndex_Success() public {
        arrayStorage.addAddress(ADDR1);
        arrayStorage.addAddress(ADDR2);
        arrayStorage.addAddress(ADDR3);

        arrayStorage.removeAddressAtIndex(1);

        assertEq(arrayStorage.getAddressArrayLength(), 2);
        assertFalse(arrayStorage.containsAddress(ADDR2));
    }

    function testRemoveAddressAtIndex_IndexOutOfBounds() public {
        arrayStorage.addAddress(ADDR1);

        vm.expectRevert(ArrayUtilsLib.ArrayUtils__IndexOutOfBounds.selector);
        arrayStorage.removeAddressAtIndex(1);
    }

    function testFindAddressIndex_Found() public {
        arrayStorage.addAddress(ADDR1);
        arrayStorage.addAddress(ADDR2);
        arrayStorage.addAddress(ADDR3);

        (bool found, uint256 index) = arrayStorage.findAddressIndex(ADDR2);
        assertTrue(found);
        assertEq(index, 1);
    }

    function testFindAddressIndex_NotFound() public {
        arrayStorage.addAddress(ADDR1);

        (bool found, uint256 index) = arrayStorage.findAddressIndex(ADDR2);
        assertFalse(found);
        assertEq(index, 0);
    }

    function testContainsAddress() public {
        arrayStorage.addAddress(ADDR1);
        arrayStorage.addAddress(ADDR2);

        assertTrue(arrayStorage.containsAddress(ADDR1));
        assertTrue(arrayStorage.containsAddress(ADDR2));
        assertFalse(arrayStorage.containsAddress(ADDR3));
    }

    // ============================================================================
    // UINT256 ARRAY TESTS
    // ============================================================================

    function testRemoveUint256Element_Success() public {
        arrayStorage.addUint256(100);
        arrayStorage.addUint256(200);
        arrayStorage.addUint256(300);

        assertEq(arrayStorage.getUint256ArrayLength(), 3);

        bool success = arrayStorage.removeUint256Element(200);
        assertTrue(success);
        assertEq(arrayStorage.getUint256ArrayLength(), 2);

        assertFalse(arrayStorage.containsUint256(200));
        assertTrue(arrayStorage.containsUint256(100));
        assertTrue(arrayStorage.containsUint256(300));
    }

    function testRemoveUint256Element_NotFound() public {
        arrayStorage.addUint256(100);

        bool success = arrayStorage.removeUint256Element(200);
        assertFalse(success);
        assertEq(arrayStorage.getUint256ArrayLength(), 1);
    }

    function testRemoveUint256AtIndex_Success() public {
        arrayStorage.addUint256(100);
        arrayStorage.addUint256(200);
        arrayStorage.addUint256(300);

        arrayStorage.removeUint256AtIndex(1);

        assertEq(arrayStorage.getUint256ArrayLength(), 2);
        assertFalse(arrayStorage.containsUint256(200));
    }

    function testRemoveUint256AtIndex_IndexOutOfBounds() public {
        arrayStorage.addUint256(100);

        vm.expectRevert(ArrayUtilsLib.ArrayUtils__IndexOutOfBounds.selector);
        arrayStorage.removeUint256AtIndex(1);
    }

    function testFindUint256Index_Found() public {
        arrayStorage.addUint256(100);
        arrayStorage.addUint256(200);
        arrayStorage.addUint256(300);

        (bool found, uint256 index) = arrayStorage.findUint256Index(200);
        assertTrue(found);
        assertEq(index, 1);
    }

    function testFindUint256Index_NotFound() public {
        arrayStorage.addUint256(100);

        (bool found, uint256 index) = arrayStorage.findUint256Index(200);
        assertFalse(found);
        assertEq(index, 0);
    }

    function testContainsUint256() public {
        arrayStorage.addUint256(100);
        arrayStorage.addUint256(200);

        assertTrue(arrayStorage.containsUint256(100));
        assertTrue(arrayStorage.containsUint256(200));
        assertFalse(arrayStorage.containsUint256(300));
    }
}
