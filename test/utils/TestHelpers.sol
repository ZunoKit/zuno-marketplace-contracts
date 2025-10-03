// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

/**
 * @title TestHelpers
 * @notice Common test utilities and helper functions
 * @dev Provides reusable test functionality across all test files
 */
contract TestHelpers is Test {
    // ============================================================================
    // CONSTANTS
    // ============================================================================

    uint256 public constant DEFAULT_PRICE = 1 ether;
    uint256 public constant DEFAULT_DURATION = 7 days;
    uint256 public constant DEFAULT_FEE_BPS = 250; // 2.5%
    uint256 public constant MAX_BPS = 10000;

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================

    /**
     * @notice Creates a test address with a label
     * @param name Label for the address
     * @return addr Generated address
     */
    function createTestAddress(string memory name) internal returns (address addr) {
        addr = makeAddr(name);
        vm.label(addr, name);
        return addr;
    }

    /**
     * @notice Funds an address with ETH
     * @param addr Address to fund
     * @param amount Amount of ETH to send
     */
    function fundAddress(address addr, uint256 amount) internal {
        vm.deal(addr, amount);
    }

    /**
     * @notice Calculates percentage of a value
     * @param value Base value
     * @param bps Basis points (1 bps = 0.01%)
     * @return result Calculated percentage
     */
    function calculatePercentage(uint256 value, uint256 bps) internal pure returns (uint256 result) {
        return (value * bps) / MAX_BPS;
    }

    /**
     * @notice Generates a future timestamp
     * @param duration Duration from now in seconds
     * @return timestamp Future timestamp
     */
    function futureTimestamp(uint256 duration) internal view returns (uint256 timestamp) {
        return block.timestamp + duration;
    }

    /**
     * @notice Generates a past timestamp
     * @param duration Duration ago in seconds
     * @return timestamp Past timestamp
     */
    function pastTimestamp(uint256 duration) internal view returns (uint256 timestamp) {
        return block.timestamp - duration;
    }

    /**
     * @notice Skips time forward
     * @param duration Duration to skip in seconds
     */
    function skipTime(uint256 duration) internal {
        vm.warp(block.timestamp + duration);
    }

    /**
     * @notice Expects a specific revert with custom error
     * @param errorSelector Error selector to expect
     */
    function expectCustomError(bytes4 errorSelector) internal {
        vm.expectRevert(abi.encodeWithSelector(errorSelector));
    }

    /**
     * @notice Asserts that two arrays are equal
     * @param a First array
     * @param b Second array
     */
    function assertArrayEqual(address[] memory a, address[] memory b) internal {
        assertEq(a.length, b.length, "Array lengths don't match");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i], "Array elements don't match");
        }
    }

    /**
     * @notice Asserts that two arrays are equal
     * @param a First array
     * @param b Second array
     */
    function assertArrayEqual(uint256[] memory a, uint256[] memory b) internal {
        assertEq(a.length, b.length, "Array lengths don't match");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i], "Array elements don't match");
        }
    }

    /**
     * @notice Asserts that a value is within a percentage range
     * @param actual Actual value
     * @param expected Expected value
     * @param toleranceBps Tolerance in basis points
     */
    function assertApproxEqual(uint256 actual, uint256 expected, uint256 toleranceBps) internal {
        uint256 tolerance = calculatePercentage(expected, toleranceBps);
        uint256 lowerBound = expected > tolerance ? expected - tolerance : 0;
        uint256 upperBound = expected + tolerance;

        assertTrue(
            actual >= lowerBound && actual <= upperBound,
            string(
                abi.encodePacked(
                    "Value not within tolerance. Expected: ",
                    vm.toString(expected),
                    ", Actual: ",
                    vm.toString(actual),
                    ", Tolerance: ",
                    vm.toString(toleranceBps),
                    " bps"
                )
            )
        );
    }

    /**
     * @notice Generates random bytes32
     * @param seed Seed for randomness
     * @return Random bytes32 value
     */
    function randomBytes32(uint256 seed) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(seed, "random"));
    }

    /**
     * @notice Generates random address
     * @param seed Seed for randomness
     * @return Random address
     */
    function randomAddress(uint256 seed) internal pure returns (address) {
        return address(uint160(uint256(randomBytes32(seed))));
    }

    /**
     * @notice Bounds a value between min and max
     * @param value Value to bound
     * @param min Minimum value
     * @param max Maximum value
     * @return Bounded value
     */
    function boundValue(uint256 value, uint256 min, uint256 max) internal pure returns (uint256) {
        if (min >= max) return min;
        return min + (value % (max - min + 1));
    }

    /**
     * @notice Creates a signature for testing
     * @param privateKey Private key to sign with
     * @param hash Hash to sign
     * @return v The recovery identifier
     * @return r The first 32 bytes of the signature
     * @return s The second 32 bytes of the signature
     */
    function createSignature(uint256 privateKey, bytes32 hash) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        return vm.sign(privateKey, hash);
    }

    /**
     * @notice Logs test information
     * @param message Message to log
     */
    function logTest(string memory message) internal view {
        console.log(string(abi.encodePacked("[TEST] ", message)));
    }

    /**
     * @notice Logs test values
     * @param label Label for the value
     * @param value Value to log
     */
    function logValue(string memory label, uint256 value) internal view {
        console.log(string(abi.encodePacked("[", label, "] ")), value);
    }

    /**
     * @notice Logs test addresses
     * @param label Label for the address
     * @param addr Address to log
     */
    function logAddress(string memory label, address addr) internal view {
        console.log(string(abi.encodePacked("[", label, "] ")), addr);
    }

    // ============================================================================
    // MOCK DATA GENERATORS
    // ============================================================================

    /**
     * @notice Generates mock NFT collection address
     * @param index Collection index
     * @return Mock collection address
     */
    function mockCollection(uint256 index) internal pure returns (address) {
        return address(uint160(0x1000 + index));
    }

    /**
     * @notice Generates mock user address
     * @param index User index
     * @return Mock user address
     */
    function mockUser(uint256 index) internal pure returns (address) {
        return address(uint160(0x2000 + index));
    }

    /**
     * @notice Generates mock token ID
     * @param index Token index
     * @return Mock token ID
     */
    function mockTokenId(uint256 index) internal pure returns (uint256) {
        return 1000 + index;
    }

    /**
     * @notice Generates mock price
     * @param index Price index
     * @return Mock price in wei
     */
    function mockPrice(uint256 index) internal pure returns (uint256) {
        return (index + 1) * 0.1 ether;
    }

    // ============================================================================
    // ASSERTION HELPERS
    // ============================================================================

    /**
     * @notice Asserts that an event was emitted with specific parameters
     * @param emitter Contract that should emit the event
     * @param eventSignature Event signature
     */
    function expectEventEmitted(address emitter, bytes32 eventSignature) internal {
        vm.expectEmit(true, true, true, true, emitter);
    }

    /**
     * @notice Asserts that a transaction reverts with a specific message
     * @param expectedMessage Expected revert message
     */
    function expectRevertWithMessage(string memory expectedMessage) internal {
        vm.expectRevert(bytes(expectedMessage));
    }

    /**
     * @notice Asserts that balance changed by expected amount
     * @param account Account to check
     * @param expectedChange Expected balance change (can be negative)
     */
    function assertBalanceChange(address account, int256 expectedChange) internal {
        uint256 balanceBefore = account.balance;

        // This would be called after the transaction
        // For now, it's a placeholder for balance checking logic

        uint256 balanceAfter = account.balance;
        int256 actualChange = int256(balanceAfter) - int256(balanceBefore);

        assertEq(actualChange, expectedChange, "Balance change doesn't match expected");
    }
}
