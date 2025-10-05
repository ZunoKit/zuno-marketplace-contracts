// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IFeeRegistry} from "../interfaces/registry/IFeeRegistry.sol";
import {IBaseFee} from "../interfaces/core/IBaseFee.sol";
import {IAdvancedFeeManager} from "../interfaces/core/IAdvancedFeeManager.sol";
import {IAdvancedRoyaltyManager} from "../interfaces/core/IAdvancedRoyaltyManager.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title FeeRegistry
 * @notice Central registry for unified fee management
 * @dev Provides single point of access for all fee calculations
 */
contract FeeRegistry is IFeeRegistry, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IBaseFee private s_baseFeeContract;
    IAdvancedFeeManager private s_feeManagerContract;
    IAdvancedRoyaltyManager private s_royaltyManagerContract;

    error FeeRegistry__ZeroAddress();
    error FeeRegistry__ContractNotSet();

    constructor(address admin, address baseFee, address feeManager, address royaltyManager) {
        if (baseFee == address(0) || feeManager == address(0) || royaltyManager == address(0)) {
            revert FeeRegistry__ZeroAddress();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);

        s_baseFeeContract = IBaseFee(baseFee);
        s_feeManagerContract = IAdvancedFeeManager(feeManager);
        s_royaltyManagerContract = IAdvancedRoyaltyManager(royaltyManager);
    }

    /**
     * @inheritdoc IFeeRegistry
     */
    function calculateAllFees(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (FeeBreakdown memory breakdown)
    {
        // Calculate platform fee
        breakdown.platformFee = s_feeManagerContract.calculateFee(salePrice);

        // Calculate royalty
        (breakdown.royaltyRecipient, breakdown.royaltyFee) =
            s_royaltyManagerContract.getRoyaltyInfo(nftContract, tokenId, salePrice);

        // Calculate totals
        breakdown.totalFees = breakdown.platformFee + breakdown.royaltyFee;
        breakdown.sellerProceeds = salePrice - breakdown.totalFees;

        return breakdown;
    }

    /**
     * @inheritdoc IFeeRegistry
     */
    function calculatePlatformFee(uint256 salePrice) external view override returns (uint256) {
        return s_feeManagerContract.calculateFee(salePrice);
    }

    /**
     * @inheritdoc IFeeRegistry
     */
    function calculateRoyalty(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address recipient, uint256 amount)
    {
        return s_royaltyManagerContract.getRoyaltyInfo(nftContract, tokenId, salePrice);
    }

    /**
     * @inheritdoc IFeeRegistry
     */
    function getPlatformFeePercentage() external view override returns (uint256) {
        return s_feeManagerContract.getTakerFee();
    }

    /**
     * @inheritdoc IFeeRegistry
     */
    function getBaseFeeContract() external view override returns (address) {
        return address(s_baseFeeContract);
    }

    /**
     * @inheritdoc IFeeRegistry
     */
    function getFeeManagerContract() external view override returns (address) {
        return address(s_feeManagerContract);
    }

    /**
     * @inheritdoc IFeeRegistry
     */
    function getRoyaltyManagerContract() external view override returns (address) {
        return address(s_royaltyManagerContract);
    }

    /**
     * @inheritdoc IFeeRegistry
     */
    function updateFeeContracts(address baseFee, address feeManager, address royaltyManager)
        external
        override
        onlyRole(ADMIN_ROLE)
    {
        if (baseFee == address(0) || feeManager == address(0) || royaltyManager == address(0)) {
            revert FeeRegistry__ZeroAddress();
        }

        s_baseFeeContract = IBaseFee(baseFee);
        s_feeManagerContract = IAdvancedFeeManager(feeManager);
        s_royaltyManagerContract = IAdvancedRoyaltyManager(royaltyManager);

        emit FeeContractsUpdated(baseFee, feeManager, royaltyManager);
    }
}
