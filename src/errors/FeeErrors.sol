// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title FeeErrors
 * @notice Custom errors for Fee contracts
 */

/// @notice Thrown when royalty fee exceeds maximum allowed (100%)
error Fee__InvalidRoyaltyFee();

/// @notice Thrown when trying to set zero address as owner
error Fee__InvalidOwner();

// ============================================================================
// ADVANCED FEE MANAGER ERRORS
// ============================================================================

/// @notice Thrown when fee parameters are invalid
error AdvancedFeeManager__InvalidFeeParams();

/// @notice Thrown when discount exceeds maximum allowed
error AdvancedFeeManager__InvalidDiscount();

/// @notice Thrown when tier configuration is invalid
error AdvancedFeeManager__InvalidTierConfig();

/// @notice Thrown when user volume data is invalid
error AdvancedFeeManager__InvalidVolumeData();

/// @notice Thrown when VIP status configuration is invalid
error AdvancedFeeManager__InvalidVIPConfig();

/// @notice Thrown when collection override is invalid
error AdvancedFeeManager__InvalidCollectionOverride();

/// @notice Thrown when array lengths don't match
error AdvancedFeeManager__ArrayLengthMismatch();

/// @notice Thrown when fee calculation fails
error AdvancedFeeManager__CalculationFailed();
