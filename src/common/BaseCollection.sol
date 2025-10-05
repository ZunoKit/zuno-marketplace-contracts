// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CollectionParams, MintStage} from "src/types/ListingTypes.sol";
import {Fee} from "src/common/Fee.sol";
import "src/errors/CollectionErrors.sol";
import {StageUpdated} from "src/events/CollectionEvents.sol";

contract BaseCollection is Ownable {
    string public s_description;
    uint256 public s_mintPrice; // Fallback mint price (wei)
    uint256 public s_maxSupply; // Maximum NFT supply
    uint256 public s_mintLimitPerWallet; // Mint limit per wallet
    uint256 public s_mintStartTime; // Mint start time
    uint256 public s_totalMinted; // Total minted
    uint256 public s_royaltyFee; // Royalty fee in basis points
    string public s_tokenURI;
    mapping(address => uint256) public s_mintedPerWallet;
    Fee public s_feeContract; // Fee contract for royalty management

    MintStage public s_currentStage;
    uint256 public s_allowlistMintPrice; // Mint price for allowlist
    uint256 public s_publicMintPrice; // Mint price for public
    uint256 public s_allowlistStageEnd; // End time for allowlist stage
    mapping(address => bool) public s_allowlist; // Allowlist
    uint256 public s_tokenIdCounter;

    constructor(CollectionParams memory params) Ownable(params.owner) {
        s_description = params.description;
        s_mintPrice = params.mintPrice;
        s_maxSupply = params.maxSupply;
        s_mintLimitPerWallet = params.mintLimitPerWallet;
        s_mintStartTime = params.mintStartTime;
        s_allowlistMintPrice = params.allowlistMintPrice;
        s_publicMintPrice = params.publicMintPrice;
        s_allowlistStageEnd = params.mintStartTime + params.allowlistStageDuration;
        s_currentStage = MintStage.INACTIVE;
        s_tokenURI = params.tokenURI;
        s_royaltyFee = params.royaltyFee;

        // Create Fee contract for royalty management
        s_feeContract = new Fee(params.owner, params.royaltyFee);
    }

    // Add addresses to allowlist
    function addToAllowlist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            s_allowlist[addresses[i]] = true;
        }
    }

    // Update mint stage (can be called manually or automatically)
    function updateMintStage() public {
        MintStage newStage = _calculateCurrentStage();
        if (newStage != s_currentStage) {
            s_currentStage = newStage;
            emit StageUpdated(s_currentStage, block.timestamp);
        }
    }

    // Internal function to calculate current stage based on time
    function _calculateCurrentStage() internal view returns (MintStage) {
        if (block.timestamp < s_mintStartTime) {
            return MintStage.INACTIVE;
        } else if (block.timestamp < s_allowlistStageEnd) {
            return MintStage.ALLOWLIST;
        } else {
            return MintStage.PUBLIC;
        }
    }

    // Auto-update stage and return current stage
    function getCurrentStageWithUpdate() public returns (MintStage) {
        updateMintStage();
        return s_currentStage;
    }

    // Check mint conditions
    function checkMint(address to, uint256 amount) internal returns (uint256 requiredPayment) {
        _validateMintConditions(to, amount);
        return _calculateRequiredPayment(amount);
    }

    // Validate mint conditions with auto stage update
    function _validateMintConditions(address to, uint256 amount) internal {
        // Auto-update stage based on current time
        MintStage currentStage = _calculateCurrentStage();
        if (currentStage != s_currentStage) {
            s_currentStage = currentStage;
            emit StageUpdated(s_currentStage, block.timestamp);
        }

        // Check if minting is active
        if (block.timestamp < s_mintStartTime) {
            revert Collection__MintingNotActive();
        }
        if (s_currentStage == MintStage.INACTIVE) {
            revert Collection__MintingNotStarted();
        }

        // Check mint limits
        if (s_mintedPerWallet[to] + amount > s_mintLimitPerWallet) {
            revert Collection__MintLimitExceeded();
        }
        if (s_totalMinted + amount > s_maxSupply) {
            revert Collection__MintLimitExceeded();
        }

        // Check allowlist if in allowlist stage
        if (s_currentStage == MintStage.ALLOWLIST) {
            if (!s_allowlist[to]) revert Collection__NotInAllowlist();
        }
    }

    // Calculate required payment
    function _calculateRequiredPayment(uint256 amount) internal view returns (uint256) {
        if (amount == 0) revert Collection__InvalidAmount();
        // Use calculated stage instead of stored stage for real-time calculation
        MintStage currentStage = _calculateCurrentStage();
        return currentStage == MintStage.ALLOWLIST ? s_allowlistMintPrice * amount : s_publicMintPrice * amount;
    }

    // Getter functions
    function getDescription() external view returns (string memory) {
        return s_description;
    }

    function getMintPrice() external view returns (uint256) {
        // Return current mint price based on stage
        MintStage currentStage = _calculateCurrentStage();
        return currentStage == MintStage.ALLOWLIST ? s_allowlistMintPrice : s_publicMintPrice;
    }

    function getMaxSupply() external view returns (uint256) {
        return s_maxSupply;
    }

    function getMintLimitPerWallet() external view returns (uint256) {
        return s_mintLimitPerWallet;
    }

    function getMintStartTime() external view returns (uint256) {
        return s_mintStartTime;
    }

    function getTotalMinted() external view returns (uint256) {
        return s_totalMinted;
    }

    function getCurrentStage() external view returns (MintStage) {
        // Return calculated stage based on current time, not stored stage
        return _calculateCurrentStage();
    }

    function getAllowlistMintPrice() external view returns (uint256) {
        return s_allowlistMintPrice;
    }

    function getPublicMintPrice() external view returns (uint256) {
        return s_publicMintPrice;
    }

    function getAllowlistStageEnd() external view returns (uint256) {
        return s_allowlistStageEnd;
    }

    function isInAllowlist(address account) external view returns (bool) {
        return s_allowlist[account];
    }

    function getMintedPerWallet(address account) external view returns (uint256) {
        return s_mintedPerWallet[account];
    }

    function getRoyaltyFee() external view returns (uint256) {
        return s_royaltyFee;
    }

    function getFeeContract() external view returns (Fee) {
        return s_feeContract;
    }

    // Debug function to get all mint info at once
    function getMintInfo(address account)
        external
        view
        returns (
            uint256 currentTime,
            uint256 mintStartTime,
            uint256 allowlistStageEnd,
            MintStage currentStage,
            uint256 currentMintPrice,
            uint256 allowlistPrice,
            uint256 publicPrice,
            uint256 totalMinted,
            uint256 maxSupply,
            uint256 mintedPerWallet,
            uint256 mintLimitPerWallet,
            bool accountInAllowlist
        )
    {
        currentTime = block.timestamp;
        mintStartTime = s_mintStartTime;
        allowlistStageEnd = s_allowlistStageEnd;
        currentStage = _calculateCurrentStage();
        currentMintPrice = currentStage == MintStage.ALLOWLIST ? s_allowlistMintPrice : s_publicMintPrice;
        allowlistPrice = s_allowlistMintPrice;
        publicPrice = s_publicMintPrice;
        totalMinted = s_totalMinted;
        maxSupply = s_maxSupply;
        mintedPerWallet = s_mintedPerWallet[account];
        mintLimitPerWallet = s_mintLimitPerWallet;
        accountInAllowlist = s_allowlist[account];
    }
}
