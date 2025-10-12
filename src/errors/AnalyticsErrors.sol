// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title AnalyticsErrors
 * @notice Custom errors for analytics and tracking operations
 * @dev Provides gas-efficient error handling for ListingHistoryTracker
 */
contract AnalyticsErrors {
    // ============================================================================
    // ANALYTICS ERRORS
    // ============================================================================

    /// @notice Thrown when collection address is invalid
    error Analytics__InvalidCollection();

    /// @notice Thrown when user address is invalid
    error Analytics__InvalidUser();

    /// @notice Thrown when timestamp is invalid
    error Analytics__InvalidTimestamp();

    /// @notice Thrown when batch size exceeds maximum limit
    error Analytics__BatchLimitExceeded();

    /// @notice Thrown when trying to access non-tracked collection
    error Analytics__CollectionNotTracked();

    /// @notice Thrown when trying to record transaction for paused contract
    error Analytics__ContractPaused();

    /// @notice Thrown when trying to access data for non-existent day
    error Analytics__DayNotFound();

    /// @notice Thrown when trying to access data for future day
    error Analytics__FutureDay();

    /// @notice Thrown when array length mismatch in batch operations
    error Analytics__ArrayLengthMismatch();

    /// @notice Thrown when trying to access data beyond maximum history entries
    error Analytics__HistoryLimitExceeded();

    /// @notice Thrown when trying to access data beyond maximum price points
    error Analytics__PricePointsLimitExceeded();
}
