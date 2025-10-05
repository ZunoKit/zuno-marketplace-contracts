// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "src/core/collection/CollectionVerifier.sol";
import "src/core/access/MarketplaceAccessControl.sol";
import "src/errors/CollectionErrors.sol";
import "../../mocks/MockERC721.sol";

contract CollectionVerifierTest is Test {
    CollectionVerifier public verifier;
    MarketplaceAccessControl public accessControl;
    MockERC721 public mockNFT;

    address public owner = address(0x1);
    address public feeRecipient = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public verifierRole = address(0x5);
    address public admin = address(0x6);
    address public moderator = address(0x7);

    uint256 public constant VERIFICATION_FEE = 0.1 ether;

    event CollectionVerified(
        address indexed collection, address indexed verifiedBy, string verificationTier, uint256 timestamp
    );

    event VerificationRequested(
        address indexed collection, address indexed requester, uint256 feePaid, uint256 timestamp
    );

    event CollectionVerificationRevoked(
        address indexed collection, address indexed revokedBy, string reason, uint256 timestamp
    );

    function setUp() public {
        vm.startPrank(owner);

        // Deploy access control
        accessControl = new MarketplaceAccessControl();

        // Deploy collection verifier
        verifier = new CollectionVerifier(address(accessControl), feeRecipient, VERIFICATION_FEE);

        // Deploy mock NFT
        mockNFT = new MockERC721("Test NFT", "TEST");

        // Grant roles
        accessControl.grantRoleWithReason(accessControl.VERIFIER_ROLE(), verifierRole, "Test verifier");

        accessControl.grantRoleWithReason(accessControl.ADMIN_ROLE(), admin, "Test admin");

        accessControl.grantRoleWithReason(accessControl.MODERATOR_ROLE(), moderator, "Test moderator");

        vm.stopPrank();

        // Give users some ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testInitialState() public {
        assertEq(verifier.verificationFee(), VERIFICATION_FEE);
        assertEq(verifier.feeRecipient(), feeRecipient);
        assertFalse(verifier.verifiedOnlyMode());
        assertEq(verifier.totalVerifiedCollections(), 0);
        assertEq(verifier.totalRequestsProcessed(), 0);
    }

    function testRequestVerification() public {
        vm.startPrank(user1);

        // Create metadata
        string[] memory tags = new string[](2);
        tags[0] = "Art";
        tags[1] = "Digital";

        CollectionVerifier.CollectionMetadata memory metadata = CollectionVerifier.CollectionMetadata({
            name: "Test Collection",
            description: "A test NFT collection",
            imageUrl: "https://example.com/image.png",
            websiteUrl: "https://example.com",
            twitterUrl: "https://twitter.com/test",
            discordUrl: "https://discord.gg/test",
            creator: user1,
            createdAt: block.timestamp,
            tags: tags,
            isActive: true
        });

        vm.expectEmit(true, true, true, true);
        emit VerificationRequested(address(mockNFT), user1, VERIFICATION_FEE, block.timestamp);

        // Request verification
        verifier.requestVerification{value: VERIFICATION_FEE}(
            address(mockNFT), metadata, "Please verify this collection"
        );

        // Check request was created
        CollectionVerifier.VerificationRequest memory request = verifier.getVerificationRequest(address(mockNFT));
        assertEq(request.collection, address(mockNFT));
        assertEq(request.requester, user1);
        assertEq(uint256(request.status), uint256(CollectionVerifier.VerificationStatus.PENDING));
        assertEq(request.feePaid, VERIFICATION_FEE);

        // Check metadata was stored
        CollectionVerifier.CollectionMetadata memory storedMetadata = verifier.getCollectionMetadata(address(mockNFT));
        assertEq(storedMetadata.name, "Test Collection");
        assertEq(storedMetadata.creator, user1);

        // Check pending requests
        address[] memory pendingRequests = verifier.getPendingRequests();
        assertEq(pendingRequests.length, 1);
        assertEq(pendingRequests[0], address(mockNFT));

        vm.stopPrank();
    }

    function testRequestVerificationInsufficientFee() public {
        vm.startPrank(user1);

        string[] memory tags = new string[](0);
        CollectionVerifier.CollectionMetadata memory metadata = CollectionVerifier.CollectionMetadata({
            name: "Test Collection",
            description: "A test NFT collection",
            imageUrl: "",
            websiteUrl: "",
            twitterUrl: "",
            discordUrl: "",
            creator: user1,
            createdAt: block.timestamp,
            tags: tags,
            isActive: true
        });

        vm.expectRevert(Collection__InsufficientFee.selector);
        verifier.requestVerification{value: 0.05 ether}(address(mockNFT), metadata, "Please verify this collection");

        vm.stopPrank();
    }

    function testProcessVerificationRequestApprove() public {
        // First request verification
        vm.startPrank(user1);

        string[] memory tags = new string[](0);
        CollectionVerifier.CollectionMetadata memory metadata = CollectionVerifier.CollectionMetadata({
            name: "Test Collection",
            description: "A test NFT collection",
            imageUrl: "",
            websiteUrl: "",
            twitterUrl: "",
            discordUrl: "",
            creator: user1,
            createdAt: block.timestamp,
            tags: tags,
            isActive: true
        });

        verifier.requestVerification{value: VERIFICATION_FEE}(
            address(mockNFT), metadata, "Please verify this collection"
        );

        vm.stopPrank();

        // Process verification (approve)
        vm.startPrank(verifierRole);

        vm.expectEmit(true, true, true, true);
        emit CollectionVerified(address(mockNFT), verifierRole, "Blue", block.timestamp);

        verifier.processVerificationRequest(
            address(mockNFT),
            true, // approve
            "Blue",
            "Collection meets verification criteria",
            0 // no expiry
        );

        vm.stopPrank();

        // Check verification was created
        assertTrue(verifier.isCollectionVerified(address(mockNFT)));

        CollectionVerifier.CollectionVerification memory verification =
            verifier.getCollectionVerification(address(mockNFT));
        assertTrue(verification.isVerified);
        assertEq(uint256(verification.status), uint256(CollectionVerifier.VerificationStatus.APPROVED));
        assertEq(verification.verifiedBy, verifierRole);
        assertEq(verification.verificationTier, "Blue");

        // Check verified collections array
        address[] memory verifiedCollections = verifier.getAllVerifiedCollections();
        assertEq(verifiedCollections.length, 1);
        assertEq(verifiedCollections[0], address(mockNFT));

        // Check statistics
        assertEq(verifier.totalVerifiedCollections(), 1);
        assertEq(verifier.totalRequestsProcessed(), 1);

        // Check pending requests is empty
        address[] memory pendingRequests = verifier.getPendingRequests();
        assertEq(pendingRequests.length, 0);
    }

    function testProcessVerificationRequestReject() public {
        // First request verification
        vm.startPrank(user1);

        string[] memory tags = new string[](0);
        CollectionVerifier.CollectionMetadata memory metadata = CollectionVerifier.CollectionMetadata({
            name: "Test Collection",
            description: "A test NFT collection",
            imageUrl: "",
            websiteUrl: "",
            twitterUrl: "",
            discordUrl: "",
            creator: user1,
            createdAt: block.timestamp,
            tags: tags,
            isActive: true
        });

        verifier.requestVerification{value: VERIFICATION_FEE}(
            address(mockNFT), metadata, "Please verify this collection"
        );

        vm.stopPrank();

        // Process verification (reject)
        vm.startPrank(verifierRole);

        verifier.processVerificationRequest(
            address(mockNFT),
            false, // reject
            "",
            "Collection does not meet criteria",
            0
        );

        vm.stopPrank();

        // Check verification was rejected
        assertFalse(verifier.isCollectionVerified(address(mockNFT)));

        CollectionVerifier.VerificationRequest memory request = verifier.getVerificationRequest(address(mockNFT));
        assertEq(uint256(request.status), uint256(CollectionVerifier.VerificationStatus.REJECTED));
        assertEq(request.reviewNotes, "Collection does not meet criteria");

        // Check statistics
        assertEq(verifier.totalVerifiedCollections(), 0);
        assertEq(verifier.totalRequestsProcessed(), 1);
    }

    function testRevokeVerification() public {
        // First verify a collection
        _verifyCollection(address(mockNFT), "Blue");

        // Revoke verification
        vm.startPrank(moderator);

        vm.expectEmit(true, true, true, true);
        emit CollectionVerificationRevoked(address(mockNFT), moderator, "Policy violation", block.timestamp);

        verifier.revokeVerification(address(mockNFT), "Policy violation");

        vm.stopPrank();

        // Check verification was revoked
        assertFalse(verifier.isCollectionVerified(address(mockNFT)));

        CollectionVerifier.CollectionVerification memory verification =
            verifier.getCollectionVerification(address(mockNFT));
        assertFalse(verification.isVerified);
        assertEq(uint256(verification.status), uint256(CollectionVerifier.VerificationStatus.REVOKED));

        // Check verified collections array is empty
        address[] memory verifiedCollections = verifier.getAllVerifiedCollections();
        assertEq(verifiedCollections.length, 0);

        // Check statistics
        assertEq(verifier.totalVerifiedCollections(), 0);
    }

    function testUpdateCollectionMetadata() public {
        // First request verification to create metadata
        vm.startPrank(user1);

        string[] memory tags = new string[](0);
        CollectionVerifier.CollectionMetadata memory metadata = CollectionVerifier.CollectionMetadata({
            name: "Test Collection",
            description: "A test NFT collection",
            imageUrl: "",
            websiteUrl: "",
            twitterUrl: "",
            discordUrl: "",
            creator: user1,
            createdAt: block.timestamp,
            tags: tags,
            isActive: true
        });

        verifier.requestVerification{value: VERIFICATION_FEE}(
            address(mockNFT), metadata, "Please verify this collection"
        );

        // Update metadata
        string[] memory newTags = new string[](1);
        newTags[0] = "Updated";

        CollectionVerifier.CollectionMetadata memory newMetadata = CollectionVerifier.CollectionMetadata({
            name: "Updated Collection",
            description: "An updated test NFT collection",
            imageUrl: "https://example.com/new-image.png",
            websiteUrl: "https://newexample.com",
            twitterUrl: "https://twitter.com/newtest",
            discordUrl: "https://discord.gg/newtest",
            creator: user1,
            createdAt: block.timestamp,
            tags: newTags,
            isActive: true
        });

        verifier.updateCollectionMetadata(address(mockNFT), newMetadata);

        // Check metadata was updated
        CollectionVerifier.CollectionMetadata memory storedMetadata = verifier.getCollectionMetadata(address(mockNFT));
        assertEq(storedMetadata.name, "Updated Collection");
        assertEq(storedMetadata.description, "An updated test NFT collection");
        assertEq(storedMetadata.websiteUrl, "https://newexample.com");

        vm.stopPrank();
    }

    function testVerifiedOnlyMode() public {
        // Initially should allow all collections
        assertTrue(verifier.canCollectionBeListed(address(mockNFT)));

        // Enable verified-only mode
        vm.startPrank(admin);
        verifier.toggleVerifiedOnlyMode(true);
        vm.stopPrank();

        // Now should not allow unverified collections
        assertFalse(verifier.canCollectionBeListed(address(mockNFT)));

        // Verify the collection
        _verifyCollection(address(mockNFT), "Blue");

        // Now should allow verified collection
        assertTrue(verifier.canCollectionBeListed(address(mockNFT)));
    }

    function testBatchVerifyCollections() public {
        MockERC721 mockNFT2 = new MockERC721("Test NFT 2", "TEST2");

        vm.startPrank(admin);

        address[] memory collections = new address[](2);
        collections[0] = address(mockNFT);
        collections[1] = address(mockNFT2);

        string[] memory tiers = new string[](2);
        tiers[0] = "Blue";
        tiers[1] = "Gold";

        verifier.batchVerifyCollections(collections, tiers);

        vm.stopPrank();

        // Check both collections are verified
        assertTrue(verifier.isCollectionVerified(address(mockNFT)));
        assertTrue(verifier.isCollectionVerified(address(mockNFT2)));

        // Check verification tiers
        CollectionVerifier.CollectionVerification memory verification1 =
            verifier.getCollectionVerification(address(mockNFT));
        CollectionVerifier.CollectionVerification memory verification2 =
            verifier.getCollectionVerification(address(mockNFT2));

        assertEq(verification1.verificationTier, "Blue");
        assertEq(verification2.verificationTier, "Gold");

        // Check statistics
        assertEq(verifier.totalVerifiedCollections(), 2);
    }

    function testGetVerificationStats() public {
        // Verify one collection
        _verifyCollection(address(mockNFT), "Blue");

        (uint256 totalVerified, uint256 totalRequests, uint256 pendingCount, bool verifiedOnlyEnabled) =
            verifier.getVerificationStats();

        assertEq(totalVerified, 1);
        assertEq(totalRequests, 1);
        assertEq(pendingCount, 0);
        assertFalse(verifiedOnlyEnabled);
    }

    function testAccessControl() public {
        // Test unauthorized verification processing
        vm.startPrank(user1);

        vm.expectRevert(Collection__UnauthorizedAccess.selector);
        verifier.processVerificationRequest(address(mockNFT), true, "Blue", "Test", 0);

        vm.stopPrank();

        // Test unauthorized revocation
        vm.startPrank(user1);

        vm.expectRevert(Collection__UnauthorizedAccess.selector);
        verifier.revokeVerification(address(mockNFT), "Test");

        vm.stopPrank();
    }

    // Helper function to verify a collection
    function _verifyCollection(address collection, string memory tier) internal {
        // Request verification
        vm.startPrank(user1);

        string[] memory tags = new string[](0);
        CollectionVerifier.CollectionMetadata memory metadata = CollectionVerifier.CollectionMetadata({
            name: "Test Collection",
            description: "A test NFT collection",
            imageUrl: "",
            websiteUrl: "",
            twitterUrl: "",
            discordUrl: "",
            creator: user1,
            createdAt: block.timestamp,
            tags: tags,
            isActive: true
        });

        verifier.requestVerification{value: VERIFICATION_FEE}(collection, metadata, "Test");

        vm.stopPrank();

        // Process verification
        vm.startPrank(verifierRole);
        verifier.processVerificationRequest(collection, true, tier, "Approved", 0);
        vm.stopPrank();
    }
}
