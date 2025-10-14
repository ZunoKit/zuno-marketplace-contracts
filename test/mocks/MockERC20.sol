// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockERC20
 * @notice Comprehensive mock ERC20 contract for testing
 * @dev Includes minting, burning, and ownership functionality
 */
contract MockERC20 is ERC20, Ownable {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimals_;
    }

    /**
     * @notice Returns the number of decimals
     * @return Number of decimals
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mints tokens to an address
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Burns tokens from an address
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /**
     * @notice Burns tokens from caller's balance
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Mints tokens to caller (for testing convenience)
     * @param amount Amount to mint
     */
    function mintToSelf(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    /**
     * @notice Batch mint to multiple addresses
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to mint
     */
    function batchMint(address[] memory recipients, uint256[] memory amounts) external {
        require(recipients.length == amounts.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }

    /**
     * @notice Sets the number of decimals (for testing purposes)
     * @param newDecimals New number of decimals
     */
    function setDecimals(uint8 newDecimals) external onlyOwner {
        _decimals = newDecimals;
    }
}
