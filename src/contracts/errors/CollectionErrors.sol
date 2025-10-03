// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Collection Errors
error Collection__MintingNotStarted();
error Collection__MintingNotActive();
error Collection__MintLimitExceeded();
error Collection__NotInAllowlist();
error Collection__InsufficientPayment();
error Collection__InvalidAmount();
error Collection__InvalidAddress();

// ============================================================================
// COLLECTION VERIFIER ERRORS
// ============================================================================

/// @notice Thrown when zero address is provided
error Collection__ZeroAddress();

/// @notice Thrown when caller lacks required permissions
error Collection__UnauthorizedAccess();

/// @notice Thrown when NFT contract is invalid
error Collection__InvalidNFTContract();

/// @notice Thrown when collection is already verified
error Collection__AlreadyVerified();

/// @notice Thrown when collection is not verified
error Collection__NotVerified();

/// @notice Thrown when verification fee is insufficient
error Collection__InsufficientFee();

/// @notice Thrown when verification request already exists
error Collection__RequestAlreadyPending();

/// @notice Thrown when verification request status is invalid
error Collection__InvalidRequestStatus();

/// @notice Thrown when fee transfer fails
error Collection__FeeTransferFailed();

/// @notice Thrown when array lengths don't match
error Collection__InvalidArrayLength();
