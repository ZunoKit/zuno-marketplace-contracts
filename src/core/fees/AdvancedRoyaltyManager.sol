// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "src/core/access/MarketplaceAccessControl.sol";
import "src/common/Fee.sol";
import "src/errors/FeeErrors.sol";
import "src/events/FeeEvents.sol";

/**
 * @title AdvancedRoyaltyManager
 * @notice Enhanced royalty management with ERC2981 support and multiple recipients
 * @dev Extends basic Fee.sol with advanced royalty features
 * @author NFT Marketplace Team
 */
contract AdvancedRoyaltyManager is Ownable, ReentrancyGuard, Pausable, ERC165, IERC2981 {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    /// @notice Access control contract
    MarketplaceAccessControl public accessControl;

    /// @notice Reference to basic Fee contract for backward compatibility
    Fee public baseFeeContract;

    /// @notice Mapping from collection to advanced royalty settings
    mapping(address => AdvancedRoyaltyInfo) public advancedRoyalties;

    /// @notice Mapping from collection to multiple recipients
    mapping(address => RoyaltyRecipient[]) public royaltyRecipients;

    /// @notice Mapping from collection to custom royalty contracts
    mapping(address => address) public customRoyaltyContracts;

    /// @notice Global royalty caps
    RoyaltyCaps public globalCaps;

    /// @notice Total royalties distributed
    uint256 public totalRoyaltiesDistributed;

    /// @notice Emergency royalty cap (10%)
    uint256 public constant EMERGENCY_ROYALTY_CAP = 1000;

    // ============================================================================
    // STRUCTS
    // ============================================================================

    /**
     * @notice Advanced royalty information for a collection
     */
    struct AdvancedRoyaltyInfo {
        bool hasAdvancedRoyalty; // Whether collection uses advanced royalty
        uint256 totalRoyaltyBps; // Total royalty percentage (basis points)
        uint256 maxRoyaltyBps; // Maximum allowed royalty for this collection
        bool useERC2981; // Whether to use ERC2981 standard
        bool allowOverrides; // Whether to allow royalty overrides
        uint256 lastUpdated; // Last update timestamp
        address updatedBy; // Who last updated the royalty
    }

    /**
     * @notice Individual royalty recipient
     */
    struct RoyaltyRecipient {
        address recipient; // Recipient address
        uint256 basisPoints; // Royalty percentage in basis points
        string role; // Role description (e.g., "creator", "platform", "charity")
        bool isActive; // Whether this recipient is active
    }

    /**
     * @notice Global royalty caps and limits
     */
    struct RoyaltyCaps {
        uint256 maxTotalRoyalty; // Maximum total royalty (basis points)
        uint256 maxSingleRecipient; // Maximum for single recipient
        uint256 maxRecipients; // Maximum number of recipients
        bool enforceGlobalCaps; // Whether to enforce global caps
    }

    // ============================================================================
    // EVENTS
    // ============================================================================

    event AdvancedRoyaltySet(
        address indexed collection, uint256 totalRoyaltyBps, uint256 recipientCount, address updatedBy
    );

    event RoyaltyRecipientAdded(
        address indexed collection, address indexed recipient, uint256 basisPoints, string role
    );

    event RoyaltyRecipientRemoved(address indexed collection, address indexed recipient);

    event RoyaltyDistributed(
        address indexed collection,
        uint256 indexed tokenId,
        uint256 salePrice,
        uint256 totalRoyalty,
        uint256 recipientCount
    );

    event CustomRoyaltyContractSet(address indexed collection, address indexed customContract);

    event RoyaltyCapsUpdated(uint256 maxTotalRoyalty, uint256 maxSingleRecipient, uint256 maxRecipients);

    // ============================================================================
    // MODIFIERS
    // ============================================================================

    /**
     * @notice Ensures caller has required role
     */
    modifier onlyRole(bytes32 role) {
        if (!accessControl.hasRole(role, msg.sender)) {
            revert Fee__InvalidOwner();
        }
        _;
    }

    /**
     * @notice Validates royalty parameters
     */
    modifier validRoyaltyParams(uint256 totalBps) {
        if (totalBps > EMERGENCY_ROYALTY_CAP) {
            revert Fee__InvalidRoyaltyFee();
        }
        _;
    }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @notice Initializes the AdvancedRoyaltyManager
     * @param _accessControl Address of the access control contract
     * @param _baseFeeContract Address of the basic Fee contract
     */
    constructor(address _accessControl, address _baseFeeContract) Ownable(msg.sender) {
        if (_accessControl == address(0) || _baseFeeContract == address(0)) {
            revert Fee__InvalidOwner();
        }

        accessControl = MarketplaceAccessControl(_accessControl);
        baseFeeContract = Fee(_baseFeeContract);

        // Initialize default caps
        globalCaps = RoyaltyCaps({
            maxTotalRoyalty: 1000, // 10%
            maxSingleRecipient: 500, // 5%
            maxRecipients: 5,
            enforceGlobalCaps: true
        });
    }

    // ============================================================================
    // ROYALTY MANAGEMENT FUNCTIONS
    // ============================================================================

    /**
     * @notice Sets advanced royalty for a collection
     * @param collection Collection address
     * @param recipients Array of royalty recipients
     * @param useERC2981 Whether to use ERC2981 standard
     */
    function setAdvancedRoyalty(address collection, RoyaltyRecipient[] calldata recipients, bool useERC2981)
        external
        onlyRole(accessControl.ADMIN_ROLE())
        nonReentrant
    {
        if (collection == address(0)) {
            revert Fee__InvalidOwner();
        }

        // Validate recipients
        uint256 totalBps = _validateRoyaltyRecipients(recipients);

        // Clear existing recipients
        delete royaltyRecipients[collection];

        // Add new recipients
        for (uint256 i = 0; i < recipients.length; i++) {
            royaltyRecipients[collection].push(recipients[i]);

            emit RoyaltyRecipientAdded(
                collection, recipients[i].recipient, recipients[i].basisPoints, recipients[i].role
            );
        }

        // Update advanced royalty info
        advancedRoyalties[collection] = AdvancedRoyaltyInfo({
            hasAdvancedRoyalty: true,
            totalRoyaltyBps: totalBps,
            maxRoyaltyBps: totalBps,
            useERC2981: useERC2981,
            allowOverrides: false,
            lastUpdated: block.timestamp,
            updatedBy: msg.sender
        });

        emit AdvancedRoyaltySet(collection, totalBps, recipients.length, msg.sender);
    }

    /**
     * @notice Calculates and distributes royalties for a sale
     * @param collection Collection address
     * @param tokenId Token ID
     * @param salePrice Sale price
     * @return totalRoyalty Total royalty amount
     * @return recipients Array of recipient addresses
     * @return amounts Array of royalty amounts
     */
    function calculateAndDistributeRoyalties(address collection, uint256 tokenId, uint256 salePrice)
        external
        view
        returns (uint256 totalRoyalty, address[] memory recipients, uint256[] memory amounts)
    {
        AdvancedRoyaltyInfo memory advancedInfo = advancedRoyalties[collection];

        if (!advancedInfo.hasAdvancedRoyalty) {
            // Fall back to basic royalty
            return _calculateBasicRoyalty(collection, tokenId, salePrice);
        }

        if (advancedInfo.useERC2981) {
            // Try ERC2981 first
            try IERC2981(collection).royaltyInfo(tokenId, salePrice) returns (address recipient, uint256 amount) {
                recipients = new address[](1);
                amounts = new uint256[](1);
                recipients[0] = recipient;
                amounts[0] = amount;
                totalRoyalty = amount;
                return (totalRoyalty, recipients, amounts);
            } catch {
                // Fall through to custom royalty calculation
            }
        }

        // Use custom royalty recipients
        return _calculateCustomRoyalty(collection, salePrice);
    }

    // ============================================================================
    // INTERNAL FUNCTIONS
    // ============================================================================

    /**
     * @notice Validates royalty recipients
     */
    function _validateRoyaltyRecipients(RoyaltyRecipient[] calldata recipients)
        internal
        view
        returns (uint256 totalBps)
    {
        if (recipients.length == 0) {
            revert Fee__InvalidRoyaltyFee();
        }

        if (globalCaps.enforceGlobalCaps && recipients.length > globalCaps.maxRecipients) {
            revert Fee__InvalidRoyaltyFee();
        }

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i].recipient == address(0)) {
                revert Fee__InvalidOwner();
            }

            if (recipients[i].basisPoints == 0) {
                revert Fee__InvalidRoyaltyFee();
            }

            if (globalCaps.enforceGlobalCaps && recipients[i].basisPoints > globalCaps.maxSingleRecipient) {
                revert Fee__InvalidRoyaltyFee();
            }

            totalBps += recipients[i].basisPoints;
        }

        if (globalCaps.enforceGlobalCaps && totalBps > globalCaps.maxTotalRoyalty) {
            revert Fee__InvalidRoyaltyFee();
        }

        return totalBps;
    }

    /**
     * @notice Calculates basic royalty using Fee contract
     */
    function _calculateBasicRoyalty(address collection, uint256 tokenId, uint256 salePrice)
        internal
        view
        returns (uint256 totalRoyalty, address[] memory recipients, uint256[] memory amounts)
    {
        try baseFeeContract.royaltyInfo(tokenId, salePrice) returns (address recipient, uint256 amount) {
            recipients = new address[](1);
            amounts = new uint256[](1);
            recipients[0] = recipient;
            amounts[0] = amount;
            totalRoyalty = amount;
        } catch {
            // No royalty
            recipients = new address[](0);
            amounts = new uint256[](0);
            totalRoyalty = 0;
        }

        return (totalRoyalty, recipients, amounts);
    }

    /**
     * @notice Calculates custom royalty using multiple recipients
     */
    function _calculateCustomRoyalty(address collection, uint256 salePrice)
        internal
        view
        returns (uint256 totalRoyalty, address[] memory recipients, uint256[] memory amounts)
    {
        RoyaltyRecipient[] memory collectionRecipients = royaltyRecipients[collection];

        // Count active recipients
        uint256 activeCount = 0;
        for (uint256 i = 0; i < collectionRecipients.length; i++) {
            if (collectionRecipients[i].isActive) {
                activeCount++;
            }
        }

        recipients = new address[](activeCount);
        amounts = new uint256[](activeCount);

        uint256 index = 0;
        for (uint256 i = 0; i < collectionRecipients.length; i++) {
            if (collectionRecipients[i].isActive) {
                recipients[index] = collectionRecipients[i].recipient;
                amounts[index] = (salePrice * collectionRecipients[i].basisPoints) / 10000;
                totalRoyalty += amounts[index];
                index++;
            }
        }

        return (totalRoyalty, recipients, amounts);
    }

    // ============================================================================
    // ERC2981 IMPLEMENTATION
    // ============================================================================

    /**
     * @notice ERC2981 royalty info implementation
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        // This is a fallback implementation
        // Individual collections should implement their own ERC2981
        return (owner(), (salePrice * 250) / 10000); // 2.5% default
    }

    /**
     * @notice ERC165 interface support
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
