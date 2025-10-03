// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC721Collection {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function owner() external view returns (address);
    function getDescription() external view returns (string memory);
    function getMintPrice() external view returns (uint256);
    function getMaxSupply() external view returns (uint256);
    function getMintLimitPerWallet() external view returns (uint256);
    function getMintStartTime() external view returns (uint256);
    function getCurrentStage() external view returns (uint256);
    function updateMintStage() external;
    function mint(address to) external payable;
    function batchMintERC721(address to, uint256 amount) external payable;
    function getMintInfo(address account)
        external
        view
        returns (
            uint256 currentTime,
            uint256 mintStartTime,
            uint256 allowlistStageEnd,
            uint256 currentStage,
            uint256 currentMintPrice,
            uint256 allowlistPrice,
            uint256 publicPrice,
            uint256 totalMinted,
            uint256 maxSupply,
            uint256 mintedPerWallet,
            uint256 mintLimitPerWallet,
            bool isInAllowlist
        );
    function ownerOf(uint256 tokenId) external view returns (address);
    function getTotalMinted() external view returns (uint256);
    function s_mintedPerWallet(address) external view returns (uint256);
    function addToAllowlist(address[] calldata addresses) external;
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
    function setRoyaltyFee(uint256 newRoyaltyFee) external;
}

interface IERC1155Collection {
    // ERC1155 functions
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
    function uri(uint256 tokenId) external view returns (string memory);

    // Collection functions
    function mint(address to, uint256 amount) external payable;
    function batchMintERC1155(address to, uint256 amount) external payable;
    function getTotalMinted() external view returns (uint256);
    function s_mintedPerWallet(address) external view returns (uint256);
    function addToAllowlist(address[] calldata addresses) external;
    function updateMintStage() external;
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
    function setRoyaltyFee(uint256 newRoyaltyFee) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
