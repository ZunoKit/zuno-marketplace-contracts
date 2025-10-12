// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/core/bundles/BundleManager.sol";
import "src/core/access/MarketplaceAccessControl.sol";
import "test/mocks/MockERC721.sol";
import "test/mocks/MockERC1155.sol";
import "test/mocks/MockERC20.sol";
import "test/mocks/MockAdvancedFeeManager.sol";
import "test/utils/TestHelpers.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract BundleManagerTest is Test, TestHelpers, IERC1155Receiver {
    BundleManager public bundleManager;
    MarketplaceAccessControl public accessControl;
    MockAdvancedFeeManager public feeManager;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;
    MockERC20 public mockERC20;

    address public admin = makeAddr("admin");
    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");

    function setUp() public {
        // Deploy access control
        vm.prank(admin);
        accessControl = new MarketplaceAccessControl();

        // Deploy fee manager
        vm.prank(admin);
        feeManager = new MockAdvancedFeeManager(admin);

        // Deploy bundle manager - admin will be the owner
        vm.prank(admin);
        bundleManager = new BundleManager(address(accessControl), address(feeManager));

        // Deploy mock contracts
        mockERC721 = new MockERC721("Test721", "T721");
        mockERC1155 = new MockERC1155("Test1155", "T1155");
        mockERC20 = new MockERC20("TestToken", "TT", 18);

        // Mint test NFTs to seller
        mockERC721.mint(seller, 1);
        mockERC721.mint(seller, 2);
        mockERC1155.mint(seller, 1, 10);
        mockERC1155.mint(seller, 2, 5);

        // Mint tokens to buyer
        mockERC20.mint(buyer, 100 ether);

        // Approve bundle manager to transfer NFTs
        vm.startPrank(seller);
        mockERC721.setApprovalForAll(address(bundleManager), true);
        mockERC1155.setApprovalForAll(address(bundleManager), true);
        vm.stopPrank();

        // Approve bundle manager to transfer tokens
        vm.prank(buyer);
        mockERC20.approve(address(bundleManager), type(uint256).max);
    }

    // Implement IERC1155Receiver interface
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function testCreateBundle() public {
        BundleManager.BundleItem[] memory items = new BundleManager.BundleItem[](2);
        items[0] = BundleManager.BundleItem({
            collection: address(mockERC721),
            tokenId: 1,
            amount: 1,
            tokenType: BundleManager.TokenType.ERC721,
            isIncluded: true
        });
        items[1] = BundleManager.BundleItem({
            collection: address(mockERC1155),
            tokenId: 1,
            amount: 3,
            tokenType: BundleManager.TokenType.ERC1155,
            isIncluded: true
        });

        vm.prank(seller);
        bytes32 bundleId = bundleManager.createBundle(
            items,
            5 ether, // total price
            1000, // 10% discount
            address(0), // ETH payment
            block.timestamp + 7 days,
            "Test Bundle",
            "https://example.com/image.png"
        );

        // Verify bundle was created
        assertTrue(bundleId != bytes32(0));

        // Check bundle details using individual getter functions
        assertEq(bundleManager.getBundleSeller(bundleId), seller);
        assertEq(bundleManager.getBundlePrice(bundleId), 5 ether);
        assertEq(uint256(bundleManager.getBundleStatus(bundleId)), uint256(BundleManager.BundleStatus.ACTIVE));

        // Verify NFTs were escrowed
        assertEq(mockERC721.ownerOf(1), address(bundleManager));
        assertEq(mockERC1155.balanceOf(address(bundleManager), 1), 3);
        assertEq(mockERC1155.balanceOf(seller, 1), 7); // 10 - 3 = 7 remaining
    }

    function testCreateBundleInvalidDiscount() public {
        BundleManager.BundleItem[] memory items = new BundleManager.BundleItem[](1);
        items[0] = BundleManager.BundleItem({
            collection: address(mockERC721),
            tokenId: 1,
            amount: 1,
            tokenType: BundleManager.TokenType.ERC721,
            isIncluded: true
        });

        vm.prank(seller);
        vm.expectRevert(); // Should revert due to excessive discount (>50%)
        bundleManager.createBundle(
            items,
            5 ether,
            6000, // 60% discount - too high
            address(0),
            block.timestamp + 7 days,
            "Test Bundle",
            ""
        );
    }

    function testPurchaseBundle() public {
        // Create bundle first
        BundleManager.BundleItem[] memory items = new BundleManager.BundleItem[](1);
        items[0] = BundleManager.BundleItem({
            collection: address(mockERC721),
            tokenId: 1,
            amount: 1,
            tokenType: BundleManager.TokenType.ERC721,
            isIncluded: true
        });

        vm.prank(seller);
        bytes32 bundleId = bundleManager.createBundle(
            items,
            1 ether,
            0, // No discount
            address(0), // ETH payment
            block.timestamp + 7 days,
            "Test Bundle",
            ""
        );

        // Purchase bundle
        vm.deal(buyer, 2 ether);
        vm.prank(buyer);
        bundleManager.purchaseBundle{value: 1 ether}(bundleId);

        // Verify bundle status changed
        assertEq(uint256(bundleManager.getBundleStatus(bundleId)), uint256(BundleManager.BundleStatus.SOLD));

        // Verify NFT was transferred to buyer
        assertEq(mockERC721.ownerOf(1), buyer);
    }

    function testPurchaseBundleWithERC20() public {
        // Create bundle with ERC20 payment
        BundleManager.BundleItem[] memory items = new BundleManager.BundleItem[](1);
        items[0] = BundleManager.BundleItem({
            collection: address(mockERC721),
            tokenId: 1,
            amount: 1,
            tokenType: BundleManager.TokenType.ERC721,
            isIncluded: true
        });

        vm.prank(seller);
        bytes32 bundleId = bundleManager.createBundle(
            items,
            10 ether, // 10 tokens
            0,
            address(mockERC20),
            block.timestamp + 7 days,
            "Test Bundle",
            ""
        );

        // Purchase bundle with ERC20
        vm.prank(buyer);
        bundleManager.purchaseBundle(bundleId);

        // Verify bundle status changed
        assertEq(uint256(bundleManager.getBundleStatus(bundleId)), uint256(BundleManager.BundleStatus.SOLD));

        // Verify NFT was transferred to buyer
        assertEq(mockERC721.ownerOf(1), buyer);

        // Verify tokens were transferred
        assertEq(mockERC20.balanceOf(buyer), 90 ether); // 100 - 10 = 90
    }

    function testCancelBundle() public {
        // Create bundle
        BundleManager.BundleItem[] memory items = new BundleManager.BundleItem[](1);
        items[0] = BundleManager.BundleItem({
            collection: address(mockERC721),
            tokenId: 1,
            amount: 1,
            tokenType: BundleManager.TokenType.ERC721,
            isIncluded: true
        });

        vm.prank(seller);
        bytes32 bundleId =
            bundleManager.createBundle(items, 1 ether, 0, address(0), block.timestamp + 7 days, "Test Bundle", "");

        // Cancel bundle
        vm.prank(seller);
        bundleManager.cancelBundle(bundleId, "Test cancellation");

        // Verify bundle status changed
        assertEq(uint256(bundleManager.getBundleStatus(bundleId)), uint256(BundleManager.BundleStatus.CANCELLED));

        // Verify NFT was returned to seller
        assertEq(mockERC721.ownerOf(1), seller);
    }

    function testUpdateBundlePrice() public {
        // Create bundle
        BundleManager.BundleItem[] memory items = new BundleManager.BundleItem[](1);
        items[0] = BundleManager.BundleItem({
            collection: address(mockERC721),
            tokenId: 1,
            amount: 1,
            tokenType: BundleManager.TokenType.ERC721,
            isIncluded: true
        });

        vm.prank(seller);
        bytes32 bundleId =
            bundleManager.createBundle(items, 1 ether, 0, address(0), block.timestamp + 7 days, "Test Bundle", "");

        // Update price
        vm.prank(seller);
        bundleManager.updateBundlePrice(bundleId, 2 ether);

        // Verify price was updated
        assertEq(bundleManager.getBundlePrice(bundleId), 2 ether);
    }

    function testGetUserBundles() public {
        // Create multiple bundles
        BundleManager.BundleItem[] memory items = new BundleManager.BundleItem[](1);
        items[0] = BundleManager.BundleItem({
            collection: address(mockERC721),
            tokenId: 1,
            amount: 1,
            tokenType: BundleManager.TokenType.ERC721,
            isIncluded: true
        });

        // Mint another NFT for second bundle first
        mockERC721.mint(seller, 3);

        vm.startPrank(seller);
        bytes32 bundleId1 =
            bundleManager.createBundle(items, 1 ether, 0, address(0), block.timestamp + 7 days, "Bundle 1", "");

        // Update items for second bundle
        items[0].tokenId = 3;

        bytes32 bundleId2 =
            bundleManager.createBundle(items, 2 ether, 0, address(0), block.timestamp + 7 days, "Bundle 2", "");
        vm.stopPrank();

        // Get user bundles
        bytes32[] memory userBundles = bundleManager.getUserBundles(seller);
        assertEq(userBundles.length, 2);
        assertEq(userBundles[0], bundleId1);
        assertEq(userBundles[1], bundleId2);
    }

    function testGetActiveBundles() public {
        // Create bundle
        BundleManager.BundleItem[] memory items = new BundleManager.BundleItem[](1);
        items[0] = BundleManager.BundleItem({
            collection: address(mockERC721),
            tokenId: 1,
            amount: 1,
            tokenType: BundleManager.TokenType.ERC721,
            isIncluded: true
        });

        vm.prank(seller);
        bytes32 bundleId =
            bundleManager.createBundle(items, 1 ether, 0, address(0), block.timestamp + 7 days, "Test Bundle", "");

        // Get active bundles
        bytes32[] memory activeBundles = bundleManager.getActiveBundles(0, 10);
        assertEq(activeBundles.length, 1);
        assertEq(activeBundles[0], bundleId);
    }

    function testAccessControl() public {
        // Non-admin should not be able to pause
        vm.prank(seller);
        vm.expectRevert();
        bundleManager.pause();
    }

    function testPauseUnpause() public {
        BundleManager.BundleItem[] memory items = new BundleManager.BundleItem[](1);
        items[0] = BundleManager.BundleItem({
            collection: address(mockERC721),
            tokenId: 1,
            amount: 1,
            tokenType: BundleManager.TokenType.ERC721,
            isIncluded: true
        });

        vm.prank(admin);
        bundleManager.pause();

        // Should not be able to create bundle when paused
        vm.prank(seller);
        vm.expectRevert();
        bundleManager.createBundle(items, 1 ether, 0, address(0), block.timestamp + 7 days, "Test Bundle", "");

        vm.prank(admin);
        bundleManager.unpause();

        // Should work after unpause
        vm.prank(seller);
        bytes32 bundleId =
            bundleManager.createBundle(items, 1 ether, 0, address(0), block.timestamp + 7 days, "Test Bundle", "");

        assertTrue(bundleId != bytes32(0));
    }
}
