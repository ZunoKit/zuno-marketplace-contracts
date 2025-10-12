// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

event FeeUpdated(string feeType, uint256 newValue);

// ============================================================================
// ADVANCED FEE MANAGER EVENTS
// ============================================================================

event FeeUpdated(
    string indexed feeType, uint256 oldValue, uint256 newValue, address indexed updatedBy, uint256 timestamp
);
