// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ============================================================================
// MARKETPLACE VALIDATOR ERRORS
// ============================================================================

/// @notice Thrown when zero address is provided
error MarketplaceValidator__ZeroAddress();

/// @notice Thrown when trying to register an already registered contract
error MarketplaceValidator__AlreadyRegistered();

/// @notice Thrown when caller is not a registered contract
error MarketplaceValidator__NotRegisteredContract();

/// @notice Thrown when NFT is not available for listing/auction
error MarketplaceValidator__NFTNotAvailable();

/// @notice Thrown when trying to list an NFT that's already in auction
error MarketplaceValidator__NFTInAuction();

/// @notice Thrown when trying to auction an NFT that's already listed
error MarketplaceValidator__NFTAlreadyListed();

/// @notice Thrown when NFT status is invalid for the requested operation
error MarketplaceValidator__InvalidNFTStatus();

/// @notice Thrown when trying to access non-existent NFT status
error MarketplaceValidator__NFTStatusNotFound();

/// @notice Thrown when caller is not authorized for the operation
error MarketplaceValidator__NotAuthorized();
