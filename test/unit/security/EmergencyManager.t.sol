// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {EmergencyManager} from "src/core/security/EmergencyManager.sol";
import {MarketplaceValidator} from "src/core/validation/MarketplaceValidator.sol";
import "src/errors/EmergencyManagerErrors.sol";
import "src/events/EmergencyManagerEvents.sol";

/**
 * @title EmergencyManagerTest
 * @notice Comprehensive unit tests for EmergencyManager contract
 * @dev Tests all emergency functions, security measures, and edge cases
 */
contract EmergencyManagerTest is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    EmergencyManager public emergencyManager;
    MarketplaceValidator public marketplaceValidator;

    address public owner;
    address public user1;
    address public user2;
    address public maliciousContract;
    address public nftContract;

    // Test constants
    uint256 public constant MIN_PAUSE_INTERVAL = 1 hours;
    uint256 public constant EMERGENCY_PAUSE_DURATION = 24 hours;

    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        // Setup test accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        maliciousContract = makeAddr("maliciousContract");
        nftContract = makeAddr("nftContract");

        // Start prank as owner
        vm.startPrank(owner);

        // Deploy MarketplaceValidator first
        marketplaceValidator = new MarketplaceValidator();

        // Deploy EmergencyManager
        emergencyManager = new EmergencyManager(address(marketplaceValidator));

        vm.stopPrank();
    }

    // ============================================================================
    // CONSTRUCTOR TESTS
    // ============================================================================

    function test_Constructor_Success() public {
        assertEq(emergencyManager.owner(), owner);
        assertEq(address(emergencyManager.marketplaceValidator()), address(marketplaceValidator));
        assertFalse(emergencyManager.paused());
    }

    function test_Constructor_RevertZeroAddress() public {
        vm.expectRevert(EmergencyManager__ZeroAddress.selector);
        new EmergencyManager(address(0));
    }

    // ============================================================================
    // EMERGENCY PAUSE TESTS
    // ============================================================================

    function test_EmergencyPause_Success() public {
        vm.startPrank(owner);

        // Test pause
        vm.expectEmit(true, false, false, true);
        emit EmergencyPauseActivated(owner, block.timestamp, "Emergency pause");

        emergencyManager.emergencyPause("Security incident");

        assertTrue(emergencyManager.paused());
        assertEq(emergencyManager.lastEmergencyPause(), block.timestamp);
    }

    function test_EmergencyPause_RevertNotOwner() public {
        vm.startPrank(user1);

        vm.expectRevert("Error message");
        emergencyManager.emergencyPause("Unauthorized attempt");
    }

    function test_EmergencyPause_RevertCooldownActive() public {
        vm.startPrank(owner);

        // First pause
        emergencyManager.emergencyPause("First pause");

        // Try to pause again immediately
        vm.expectRevert(EmergencyManager__PauseCooldownActive.selector);
        emergencyManager.emergencyPause("Second pause");
    }

    function test_EmergencyPause_SuccessAfterCooldown() public {
        vm.startPrank(owner);

        // First pause
        emergencyManager.emergencyPause("First pause");
        emergencyManager.emergencyUnpause();

        // Wait for cooldown to pass
        vm.warp(block.timestamp + MIN_PAUSE_INTERVAL + 1);

        // Should succeed now
        emergencyManager.emergencyPause("Second pause after cooldown");
        assertTrue(emergencyManager.paused());
    }

    function test_EmergencyUnpause_Success() public {
        vm.startPrank(owner);

        // Pause first
        emergencyManager.emergencyPause("Test pause");
        assertTrue(emergencyManager.paused());

        // Test unpause
        vm.expectEmit(true, false, false, true);
        emit EmergencyPauseDeactivated(owner, block.timestamp);

        emergencyManager.emergencyUnpause();
        assertFalse(emergencyManager.paused());
    }

    function test_EmergencyUnpause_RevertNotOwner() public {
        vm.startPrank(owner);
        emergencyManager.emergencyPause("Test pause");
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Error message");
        emergencyManager.emergencyUnpause();
    }

    // ============================================================================
    // CONTRACT BLACKLIST TESTS
    // ============================================================================

    function test_SetContractBlacklist_Success() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);
        emit ContractBlacklisted(maliciousContract, true, "Malicious contract");

        emergencyManager.setContractBlacklist(maliciousContract, true, "Malicious contract");

        assertTrue(emergencyManager.blacklistedContracts(maliciousContract));
        assertTrue(emergencyManager.isContractBlacklisted(maliciousContract));
    }

    function test_SetContractBlacklist_RevertZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert(EmergencyManager__ZeroAddress.selector);
        emergencyManager.setContractBlacklist(address(0), true, "Zero address");
    }

    function test_SetContractBlacklist_RevertNotOwner() public {
        vm.startPrank(user1);

        vm.expectRevert("Error message");
        emergencyManager.setContractBlacklist(maliciousContract, true, "Malicious contract");
    }

    function test_SetContractBlacklist_Unblacklist() public {
        vm.startPrank(owner);

        // Blacklist first
        emergencyManager.setContractBlacklist(maliciousContract, true, "Malicious contract");
        assertTrue(emergencyManager.isContractBlacklisted(maliciousContract));

        // Unblacklist
        vm.expectEmit(true, false, false, true);
        emit ContractBlacklisted(maliciousContract, false, "Removed from blacklist");

        emergencyManager.setContractBlacklist(maliciousContract, false, "Removed from blacklist");
        assertFalse(emergencyManager.isContractBlacklisted(maliciousContract));
    }

    // ============================================================================
    // USER BLACKLIST TESTS
    // ============================================================================

    function test_SetUserBlacklist_Success() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);
        emit UserBlacklisted(user1, true, "Blacklisted user");

        emergencyManager.setUserBlacklist(user1, true, "Blacklisted user");

        assertTrue(emergencyManager.blacklistedUsers(user1));
        assertTrue(emergencyManager.isUserBlacklisted(user1));
    }

    function test_SetUserBlacklist_RevertZeroAddress() public {
        vm.startPrank(owner);

        vm.expectRevert(EmergencyManager__ZeroAddress.selector);
        emergencyManager.setUserBlacklist(address(0), true, "Zero address");
    }

    function test_SetUserBlacklist_RevertNotOwner() public {
        vm.startPrank(user1);

        vm.expectRevert("Error message");
        emergencyManager.setUserBlacklist(user2, true, "Blacklisted user");
    }

    // ============================================================================
    // BATCH BLACKLIST TESTS
    // ============================================================================

    function test_BatchSetContractBlacklist_Success() public {
        vm.startPrank(owner);

        address[] memory contracts = new address[](3);
        contracts[0] = makeAddr("contract1");
        contracts[1] = makeAddr("contract2");
        contracts[2] = makeAddr("contract3");

        // Expect events for each contract
        for (uint256 i = 0; i < contracts.length; i++) {
            vm.expectEmit(true, false, false, true);
            emit ContractBlacklisted(contracts[i], true, "Batch blacklist");
        }

        emergencyManager.batchSetContractBlacklist(contracts, true, "Batch blacklist");

        // Verify all contracts are blacklisted
        for (uint256 i = 0; i < contracts.length; i++) {
            assertTrue(emergencyManager.isContractBlacklisted(contracts[i]));
        }
    }

    function test_BatchSetContractBlacklist_RevertEmptyArray() public {
        vm.startPrank(owner);

        address[] memory emptyArray = new address[](0);

        vm.expectRevert(EmergencyManager__EmptyArray.selector);
        emergencyManager.batchSetContractBlacklist(emptyArray, true, "Empty array");
    }

    function test_BatchSetContractBlacklist_RevertZeroAddress() public {
        vm.startPrank(owner);

        address[] memory contracts = new address[](2);
        contracts[0] = makeAddr("validContract");
        contracts[1] = address(0); // Invalid address

        vm.expectRevert(EmergencyManager__ZeroAddress.selector);
        emergencyManager.batchSetContractBlacklist(contracts, true, "Batch blacklist");
    }

    // ============================================================================
    // BULK NFT STATUS RESET TESTS
    // ============================================================================

    function test_EmergencyBulkResetNFTStatus_Success() public {
        vm.startPrank(owner);

        address[] memory nftContracts = new address[](2);
        uint256[] memory tokenIds = new uint256[](2);
        address[] memory owners = new address[](2);

        nftContracts[0] = makeAddr("nft1");
        nftContracts[1] = makeAddr("nft2");
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        owners[0] = user1;
        owners[1] = user2;

        vm.expectEmit(false, false, false, true);
        emit BulkNFTStatusReset(nftContracts, tokenIds, owners, 2);

        emergencyManager.emergencyBulkResetNFTStatus(nftContracts, tokenIds, owners);
    }

    function test_EmergencyBulkResetNFTStatus_RevertArrayLengthMismatch() public {
        vm.startPrank(owner);

        address[] memory nftContracts = new address[](2);
        uint256[] memory tokenIds = new uint256[](1); // Mismatched length
        address[] memory owners = new address[](2);

        vm.expectRevert(EmergencyManager__ArrayLengthMismatch.selector);
        emergencyManager.emergencyBulkResetNFTStatus(nftContracts, tokenIds, owners);
    }

    function test_EmergencyBulkResetNFTStatus_RevertEmptyArray() public {
        vm.startPrank(owner);

        address[] memory emptyContracts = new address[](0);
        uint256[] memory emptyTokenIds = new uint256[](0);
        address[] memory emptyOwners = new address[](0);

        vm.expectRevert(EmergencyManager__EmptyArray.selector);
        emergencyManager.emergencyBulkResetNFTStatus(emptyContracts, emptyTokenIds, emptyOwners);
    }

    // ============================================================================
    // EMERGENCY WITHDRAWAL TESTS
    // ============================================================================

    function test_EmergencyWithdraw_Success() public {
        // Send some ETH to the contract
        vm.deal(address(emergencyManager), 1 ether);

        vm.startPrank(owner);

        uint256 initialBalance = user1.balance;

        vm.expectEmit(true, false, false, true);
        emit EmergencyFundWithdrawal(user1, 0.5 ether, "Emergency withdrawal", block.timestamp);

        emergencyManager.emergencyWithdraw(payable(user1), 0.5 ether, "Emergency withdrawal");

        assertEq(user1.balance, initialBalance + 0.5 ether);
        assertEq(address(emergencyManager).balance, 0.5 ether);
    }

    function test_EmergencyWithdraw_SuccessWithdrawAll() public {
        // Send some ETH to the contract
        vm.deal(address(emergencyManager), 1 ether);

        vm.startPrank(owner);

        uint256 initialBalance = user1.balance;

        // Withdraw all (amount = 0)
        emergencyManager.emergencyWithdraw(payable(user1), 0, "Zero amount");

        assertEq(user1.balance, initialBalance + 1 ether);
        assertEq(address(emergencyManager).balance, 0);
    }

    function test_EmergencyWithdraw_RevertZeroAddress() public {
        vm.deal(address(emergencyManager), 1 ether);
        vm.startPrank(owner);

        vm.expectRevert(EmergencyManager__ZeroAddress.selector);
        emergencyManager.emergencyWithdraw(payable(address(0)), 0.5 ether, "Zero address");
    }

    function test_EmergencyWithdraw_RevertNoFunds() public {
        vm.startPrank(owner);

        vm.expectRevert(EmergencyManager__NoFundsToWithdraw.selector);
        emergencyManager.emergencyWithdraw(payable(user1), 0.5 ether, "Emergency withdrawal");
    }

    function test_EmergencyWithdraw_RevertInsufficientBalance() public {
        vm.deal(address(emergencyManager), 0.5 ether);
        vm.startPrank(owner);

        vm.expectRevert(EmergencyManager__InsufficientBalance.selector);
        emergencyManager.emergencyWithdraw(payable(user1), 1 ether, "Insufficient balance");
    }

    // ============================================================================
    // VIEW FUNCTION TESTS
    // ============================================================================

    function test_GetPauseCooldownRemaining() public {
        vm.startPrank(owner);

        // Initially no cooldown
        assertEq(emergencyManager.getPauseCooldownRemaining(), 0);

        // After pause, should have cooldown
        emergencyManager.emergencyPause("Test pause");
        assertEq(emergencyManager.getPauseCooldownRemaining(), MIN_PAUSE_INTERVAL);

        // After time passes, cooldown should decrease
        vm.warp(block.timestamp + 30 minutes);
        assertEq(emergencyManager.getPauseCooldownRemaining(), 30 minutes);

        // After full cooldown, should be 0
        vm.warp(block.timestamp + 30 minutes + 1);
        assertEq(emergencyManager.getPauseCooldownRemaining(), 0);
    }

    // ============================================================================
    // RECEIVE FUNCTION TESTS
    // ============================================================================

    function test_ReceiveETH_Success() public {
        uint256 initialBalance = address(emergencyManager).balance;

        // Send ETH to contract
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);

        (bool success,) = address(emergencyManager).call{value: 0.5 ether}("");
        assertTrue(success);

        assertEq(address(emergencyManager).balance, initialBalance + 0.5 ether);
    }

    // ============================================================================
    // INTEGRATION TESTS
    // ============================================================================

    function test_Integration_PauseAndBlacklist() public {
        vm.startPrank(owner);

        // Pause the contract
        emergencyManager.emergencyPause("Security incident");
        assertTrue(emergencyManager.paused());

        // Blacklist malicious contract
        emergencyManager.setContractBlacklist(maliciousContract, true, "Malicious contract");
        assertTrue(emergencyManager.isContractBlacklisted(maliciousContract));

        // Unpause
        emergencyManager.emergencyUnpause();
        assertFalse(emergencyManager.paused());

        // Contract should still be blacklisted
        assertTrue(emergencyManager.isContractBlacklisted(maliciousContract));
    }

    // ============================================================================
    // FUZZ TESTS
    // ============================================================================

    function testFuzz_SetContractBlacklist(address contractAddr, bool isBlacklisted) public {
        vm.assume(contractAddr != address(0));
        vm.startPrank(owner);

        emergencyManager.setContractBlacklist(contractAddr, isBlacklisted, "Test reason");
        assertEq(emergencyManager.isContractBlacklisted(contractAddr), isBlacklisted);
    }

    function testFuzz_EmergencyWithdraw(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 100 ether);

        // Give contract some ETH
        vm.deal(address(emergencyManager), amount);
        vm.startPrank(owner);

        uint256 initialBalance = user1.balance;
        emergencyManager.emergencyWithdraw(payable(user1), amount, "Test withdrawal");

        assertEq(user1.balance, initialBalance + amount);
        assertEq(address(emergencyManager).balance, 0);
    }
}
