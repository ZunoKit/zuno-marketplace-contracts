// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title EmergencyManagerErrors
 * @notice Custom errors for EmergencyManager contract
 * @dev Using custom errors instead of require strings for gas optimization
 */

// ============================================================================
// GENERAL ERRORS
// ============================================================================

/// @notice Thrown when a zero address is provided where not allowed
error EmergencyManager__ZeroAddress();

/// @notice Thrown when array lengths don't match
error EmergencyManager__ArrayLengthMismatch();

/// @notice Thrown when an empty array is provided
error EmergencyManager__EmptyArray();

// ============================================================================
// BLACKLIST ERRORS
// ============================================================================

/// @notice Thrown when trying to interact with a blacklisted contract
error EmergencyManager__ContractBlacklisted();

/// @notice Thrown when trying to interact with a blacklisted user
error EmergencyManager__UserBlacklisted();

// ============================================================================
// PAUSE ERRORS
// ============================================================================

/// @notice Thrown when trying to pause during cooldown period
error EmergencyManager__PauseCooldownActive();

/// @notice Thrown when trying to pause an already paused contract
error EmergencyManager__AlreadyPaused();

/// @notice Thrown when trying to unpause an already unpaused contract
error EmergencyManager__AlreadyUnpaused();

// ============================================================================
// WITHDRAWAL ERRORS
// ============================================================================

/// @notice Thrown when trying to withdraw but no funds available
error EmergencyManager__NoFundsToWithdraw();

/// @notice Thrown when withdrawal amount exceeds contract balance
error EmergencyManager__InsufficientBalance();

/// @notice Thrown when withdrawal transaction fails
error EmergencyManager__WithdrawalFailed();

// ============================================================================
// NFT STATUS RESET ERRORS
// ============================================================================

/// @notice Thrown when NFT status reset fails
error EmergencyManager__NFTStatusResetFailed();

/// @notice Thrown when trying to reset status for non-existent NFT
error EmergencyManager__NFTNotFound();

/// @notice Thrown when caller is not authorized to reset NFT status
error EmergencyManager__NotAuthorizedForReset();

// ============================================================================
// ACCESS CONTROL ERRORS
// ============================================================================

/// @notice Thrown when caller doesn't have required permissions
error EmergencyManager__NotAuthorized();

/// @notice Thrown when trying to perform action on invalid contract
error EmergencyManager__InvalidContract();

/// @notice Thrown when emergency action is not allowed in current state
error EmergencyManager__EmergencyActionNotAllowed();
