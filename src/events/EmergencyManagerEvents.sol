// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title EmergencyManagerEvents
 * @notice Events for EmergencyManager contract
 * @dev Comprehensive events for emergency actions and security measures
 */

// ============================================================================
// EMERGENCY PAUSE EVENTS
// ============================================================================

/**
 * @notice Emitted when emergency pause is activated
 * @param activator Address that activated the pause
 * @param timestamp When the pause was activated
 * @param reason Reason for the emergency pause
 */
event EmergencyPauseActivated(address indexed activator, uint256 timestamp, string reason);

/**
 * @notice Emitted when emergency pause is deactivated
 * @param deactivator Address that deactivated the pause
 * @param timestamp When the pause was deactivated
 */
event EmergencyPauseDeactivated(address indexed deactivator, uint256 timestamp);

// ============================================================================
// BLACKLIST EVENTS
// ============================================================================

/**
 * @notice Emitted when a contract is blacklisted or unblacklisted
 * @param contractAddress Address of the contract
 * @param isBlacklisted Whether the contract is now blacklisted
 * @param reason Reason for the blacklist action
 */
event ContractBlacklisted(address indexed contractAddress, bool isBlacklisted, string reason);

/**
 * @notice Emitted when a user is blacklisted or unblacklisted
 * @param userAddress Address of the user
 * @param isBlacklisted Whether the user is now blacklisted
 * @param reason Reason for the blacklist action
 */
event UserBlacklisted(address indexed userAddress, bool isBlacklisted, string reason);

/**
 * @notice Emitted when multiple contracts are blacklisted in batch
 * @param contractAddresses Array of contract addresses
 * @param isBlacklisted Whether the contracts are now blacklisted
 * @param reason Reason for the batch blacklist action
 * @param count Number of contracts affected
 */
event BatchContractBlacklisted(address[] contractAddresses, bool isBlacklisted, string reason, uint256 count);

// ============================================================================
// NFT STATUS RESET EVENTS
// ============================================================================

/**
 * @notice Emitted when NFT statuses are reset in bulk
 * @param nftContracts Array of NFT contract addresses
 * @param tokenIds Array of token IDs
 * @param owners Array of owner addresses
 * @param count Number of NFTs reset
 */
event BulkNFTStatusReset(address[] nftContracts, uint256[] tokenIds, address[] owners, uint256 count);

/**
 * @notice Emitted when a single NFT status is reset
 * @param nftContract Address of the NFT contract
 * @param tokenId Token ID
 * @param owner Owner address
 * @param oldStatus Previous status
 * @param newStatus New status (should be AVAILABLE)
 */
event SingleNFTStatusReset(
    address indexed nftContract, uint256 indexed tokenId, address indexed owner, uint8 oldStatus, uint8 newStatus
);

/**
 * @notice Emitted when collection-wide NFT status reset occurs
 * @param nftContract Address of the NFT contract
 * @param tokenIds Array of token IDs reset
 * @param owners Array of corresponding owners
 * @param count Number of NFTs reset in the collection
 */
event CollectionStatusReset(address indexed nftContract, uint256[] tokenIds, address[] owners, uint256 count);

// ============================================================================
// EMERGENCY WITHDRAWAL EVENTS
// ============================================================================

/**
 * @notice Emitted when emergency fund withdrawal occurs
 * @param recipient Address receiving the funds
 * @param amount Amount withdrawn
 * @param reason Reason for the withdrawal
 * @param timestamp When the withdrawal occurred
 */
event EmergencyFundWithdrawal(address indexed recipient, uint256 amount, string reason, uint256 timestamp);

/**
 * @notice Emitted when emergency withdrawal fails
 * @param recipient Intended recipient address
 * @param amount Amount that failed to withdraw
 * @param reason Reason for the attempted withdrawal
 */
event EmergencyWithdrawalFailed(address indexed recipient, uint256 amount, string reason);

// ============================================================================
// SECURITY EVENTS
// ============================================================================

/**
 * @notice Emitted when a security incident is detected
 * @param incidentType Type of security incident
 * @param affectedContract Contract involved in the incident
 * @param reporter Address that reported the incident
 * @param timestamp When the incident was reported
 * @param details Additional details about the incident
 */
event SecurityIncidentReported(
    string incidentType, address indexed affectedContract, address indexed reporter, uint256 timestamp, string details
);

/**
 * @notice Emitted when emergency manager configuration is updated
 * @param parameter Parameter that was updated
 * @param oldValue Previous value
 * @param newValue New value
 * @param updatedBy Address that made the update
 */
event EmergencyConfigUpdated(string parameter, uint256 oldValue, uint256 newValue, address indexed updatedBy);

// ============================================================================
// ACCESS CONTROL EVENTS
// ============================================================================

/**
 * @notice Emitted when emergency access is granted to an address
 * @param grantee Address receiving emergency access
 * @param grantedBy Address that granted the access
 * @param accessType Type of emergency access granted
 * @param timestamp When access was granted
 */
event EmergencyAccessGranted(address indexed grantee, address indexed grantedBy, string accessType, uint256 timestamp);

/**
 * @notice Emitted when emergency access is revoked from an address
 * @param revokee Address losing emergency access
 * @param revokedBy Address that revoked the access
 * @param accessType Type of emergency access revoked
 * @param timestamp When access was revoked
 */
event EmergencyAccessRevoked(address indexed revokee, address indexed revokedBy, string accessType, uint256 timestamp);

// ============================================================================
// CIRCUIT BREAKER EVENTS
// ============================================================================

/**
 * @notice Emitted when circuit breaker is triggered
 * @param trigger What triggered the circuit breaker
 * @param threshold Threshold that was exceeded
 * @param currentValue Current value that exceeded threshold
 * @param timestamp When circuit breaker was triggered
 */
event CircuitBreakerTriggered(string trigger, uint256 threshold, uint256 currentValue, uint256 timestamp);

/**
 * @notice Emitted when circuit breaker is reset
 * @param resetBy Address that reset the circuit breaker
 * @param timestamp When circuit breaker was reset
 */
event CircuitBreakerReset(address indexed resetBy, uint256 timestamp);
