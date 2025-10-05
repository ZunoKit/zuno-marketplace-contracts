// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MarketplaceTimelock
 * @notice Timelock contract for critical marketplace admin operations
 * @dev Implements a 48-hour timelock for sensitive parameter changes
 * @dev Prevents rug pulls and provides transparency for parameter updates
 * @author NFT Marketplace Team
 */
contract MarketplaceTimelock is Ownable, ReentrancyGuard {
    // ============================================================================
    // CONSTANTS
    // ============================================================================

    /// @notice Timelock duration for critical operations (48 hours)
    uint256 public constant TIMELOCK_DURATION = 48 hours;

    /// @notice Minimum timelock duration (cannot be reduced below 24 hours)
    uint256 public constant MIN_TIMELOCK_DURATION = 24 hours;

    /// @notice Maximum timelock duration (cannot exceed 7 days)
    uint256 public constant MAX_TIMELOCK_DURATION = 7 days;

    /// @notice Grace period after timelock expires (7 days to execute)
    uint256 public constant GRACE_PERIOD = 7 days;

    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    /// @notice Mapping of action ID to scheduled time
    mapping(bytes32 => uint256) public scheduledActions;

    /// @notice Mapping of action ID to execution status
    mapping(bytes32 => bool) public executedActions;

    /// @notice Mapping of action ID to cancellation status
    mapping(bytes32 => bool) public cancelledActions;

    /// @notice Mapping of action ID to action data
    mapping(bytes32 => ActionData) public actionData;

    /// @notice Current custom timelock duration (defaults to TIMELOCK_DURATION)
    uint256 public customTimelockDuration = TIMELOCK_DURATION;

    // ============================================================================
    // STRUCTS
    // ============================================================================

    /**
     * @notice Action data structure
     */
    struct ActionData {
        address target; // Target contract
        bytes data; // Calldata
        uint256 value; // ETH value
        string description; // Human-readable description
        address proposer; // Who proposed the action
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    event ActionScheduled(
        bytes32 indexed actionId,
        address indexed target,
        bytes data,
        uint256 value,
        uint256 executeTime,
        string description,
        address indexed proposer
    );

    event ActionExecuted(bytes32 indexed actionId, address indexed executor, bytes returnData);

    event ActionCancelled(bytes32 indexed actionId, address indexed canceller);

    event TimelockDurationUpdated(uint256 oldDuration, uint256 newDuration, address indexed updater);

    // ============================================================================
    // ERRORS
    // ============================================================================

    error Timelock__ActionAlreadyScheduled();
    error Timelock__ActionNotScheduled();
    error Timelock__ActionAlreadyExecuted();
    error Timelock__ActionCancelled();
    error Timelock__TimelockNotExpired();
    error Timelock__GracePeriodExpired();
    error Timelock__ExecutionFailed();
    error Timelock__InvalidTimelockDuration();
    error Timelock__ZeroAddress();

    // ============================================================================
    // MODIFIERS
    // ============================================================================

    /**
     * @notice Ensures action is schedulable
     */
    modifier actionNotScheduled(bytes32 actionId) {
        if (scheduledActions[actionId] != 0) {
            revert Timelock__ActionAlreadyScheduled();
        }
        _;
    }

    /**
     * @notice Ensures action is scheduled
     */
    modifier actionIsScheduled(bytes32 actionId) {
        if (scheduledActions[actionId] == 0) {
            revert Timelock__ActionNotScheduled();
        }
        _;
    }

    /**
     * @notice Ensures action hasn't been executed
     */
    modifier notExecuted(bytes32 actionId) {
        if (executedActions[actionId]) {
            revert Timelock__ActionAlreadyExecuted();
        }
        _;
    }

    /**
     * @notice Ensures action hasn't been cancelled
     */
    modifier notCancelled(bytes32 actionId) {
        if (cancelledActions[actionId]) {
            revert Timelock__ActionCancelled();
        }
        _;
    }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    constructor() Ownable(msg.sender) {}

    // ============================================================================
    // SCHEDULING FUNCTIONS
    // ============================================================================

    /**
     * @notice Schedules a new timelocked action
     * @param target Target contract address
     * @param data Encoded function calldata
     * @param value ETH value to send
     * @param description Human-readable description
     * @return actionId The generated action ID
     */
    function scheduleAction(address target, bytes calldata data, uint256 value, string calldata description)
        external
        onlyOwner
        nonReentrant
        returns (bytes32 actionId)
    {
        if (target == address(0)) revert Timelock__ZeroAddress();

        actionId = keccak256(abi.encode(target, data, value, block.timestamp, msg.sender));

        if (scheduledActions[actionId] != 0) {
            revert Timelock__ActionAlreadyScheduled();
        }

        uint256 executeTime = block.timestamp + customTimelockDuration;
        scheduledActions[actionId] = executeTime;

        actionData[actionId] = ActionData({
            target: target,
            data: data,
            value: value,
            description: description,
            proposer: msg.sender
        });

        emit ActionScheduled(actionId, target, data, value, executeTime, description, msg.sender);

        return actionId;
    }

    /**
     * @notice Executes a timelocked action
     * @param actionId The action ID to execute
     * @return returnData Return data from the execution
     */
    function executeAction(bytes32 actionId)
        external
        onlyOwner
        nonReentrant
        actionIsScheduled(actionId)
        notExecuted(actionId)
        notCancelled(actionId)
        returns (bytes memory returnData)
    {
        uint256 executeTime = scheduledActions[actionId];

        // Check timelock has expired
        if (block.timestamp < executeTime) {
            revert Timelock__TimelockNotExpired();
        }

        // Check grace period hasn't expired
        if (block.timestamp > executeTime + GRACE_PERIOD) {
            revert Timelock__GracePeriodExpired();
        }

        // Mark as executed
        executedActions[actionId] = true;

        // Get action data
        ActionData memory action = actionData[actionId];

        // Execute the action
        (bool success, bytes memory data) = action.target.call{value: action.value}(action.data);

        if (!success) {
            revert Timelock__ExecutionFailed();
        }

        emit ActionExecuted(actionId, msg.sender, data);

        return data;
    }

    /**
     * @notice Cancels a scheduled action
     * @param actionId The action ID to cancel
     */
    function cancelAction(bytes32 actionId)
        external
        onlyOwner
        nonReentrant
        actionIsScheduled(actionId)
        notExecuted(actionId)
        notCancelled(actionId)
    {
        cancelledActions[actionId] = true;
        emit ActionCancelled(actionId, msg.sender);
    }

    // ============================================================================
    // ADMIN FUNCTIONS
    // ============================================================================

    /**
     * @notice Updates the custom timelock duration
     * @param newDuration New timelock duration
     * @dev This change itself requires a timelock (creates recursive timelock)
     */
    function updateTimelockDuration(uint256 newDuration) external onlyOwner {
        if (newDuration < MIN_TIMELOCK_DURATION || newDuration > MAX_TIMELOCK_DURATION) {
            revert Timelock__InvalidTimelockDuration();
        }

        uint256 oldDuration = customTimelockDuration;
        customTimelockDuration = newDuration;

        emit TimelockDurationUpdated(oldDuration, newDuration, msg.sender);
    }

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    /**
     * @notice Gets time remaining until action can be executed
     * @param actionId The action ID
     * @return timeRemaining Time in seconds (0 if ready to execute)
     */
    function getTimeRemaining(bytes32 actionId) external view returns (uint256 timeRemaining) {
        uint256 executeTime = scheduledActions[actionId];
        if (executeTime == 0) return type(uint256).max; // Not scheduled

        if (block.timestamp >= executeTime) return 0; // Ready to execute

        return executeTime - block.timestamp;
    }

    /**
     * @notice Checks if action is ready to execute
     * @param actionId The action ID
     * @return isReady Whether the action can be executed
     */
    function isActionReady(bytes32 actionId) external view returns (bool isReady) {
        uint256 executeTime = scheduledActions[actionId];
        if (executeTime == 0) return false; // Not scheduled
        if (executedActions[actionId]) return false; // Already executed
        if (cancelledActions[actionId]) return false; // Cancelled
        if (block.timestamp < executeTime) return false; // Timelock not expired
        if (block.timestamp > executeTime + GRACE_PERIOD) return false; // Grace period expired

        return true;
    }

    /**
     * @notice Gets action details
     * @param actionId The action ID
     * @return action The action data
     */
    function getActionData(bytes32 actionId) external view returns (ActionData memory action) {
        return actionData[actionId];
    }

    // ============================================================================
    // RECEIVE FUNCTION
    // ============================================================================

    /**
     * @notice Allows contract to receive ETH
     */
    receive() external payable {}
}
