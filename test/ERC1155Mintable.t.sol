// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20; // Use ^0.8.20 to match contract

import {Test, console2} from "forge-std/Test.sol";
import {ERC1155Mintable} from "../src/ERC1155Mintable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol"; // For error selectors and interface ID
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol"; // For events and errors
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol"; // For events and errors
import {IERC1155Mintable} from "../src/interfaces/IERC1155Mintable.sol"; // Import the interface
import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol"; // For errors
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol"; // For interface ID
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol"; // For events and errors

contract ERC1155MintableTest is Test, IERC1155Receiver {
    ERC1155Mintable public erc1155;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // Define addresses for testing roles
    address deployer;
    address minter;
    address user;

    string constant BASE_URI = "https://example.com/api/token/";
    uint256 constant TOKEN_ID_1 = 1;
    uint256 constant TOKEN_ID_2 = 2;
    uint256 constant MINT_AMOUNT_1 = 100;
    uint256 constant MINT_AMOUNT_2 = 200;

    // Helper for AccessControl revert string
    function _accessControlError(address account, bytes32 role) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, account, role);
    }

    function setUp() public {
        deployer = address(this); // Default test contract address
        minter = makeAddr("minter");
        user = makeAddr("user");

        erc1155 = new ERC1155Mintable(BASE_URI, deployer);
    }

    // --- Test Constructor ---
    function test_RevertIf_AdminIsZeroAddress() public {
        vm.expectRevert(IERC1155Mintable.ERC1155MintableZeroAddressAdmin.selector);
        new ERC1155Mintable(BASE_URI, address(0));
    }

    function testConstructorWithDifferentAdmin() public {
        ERC1155Mintable newInstance = new ERC1155Mintable(BASE_URI, minter);
        
        assertTrue(newInstance.hasRole(DEFAULT_ADMIN_ROLE, minter), "Admin role not granted to specified admin");
        assertTrue(newInstance.hasRole(MINTER_ROLE, minter), "Minter role not granted to specified admin");
        
        assertFalse(newInstance.hasRole(DEFAULT_ADMIN_ROLE, deployer), "Deployer should not have admin role");
        assertFalse(newInstance.hasRole(MINTER_ROLE, deployer), "Deployer should not have minter role");
        
        vm.startPrank(minter);
        newInstance.mint(user, TOKEN_ID_1, MINT_AMOUNT_1, "");
        vm.stopPrank();
        
        assertEq(newInstance.balanceOf(user, TOKEN_ID_1), MINT_AMOUNT_1, "Mint by admin failed");
    }

    // --- Test Initial State ---
    function testInitialState() public view {
        assertEq(erc1155.uri(0), BASE_URI, "Initial URI mismatch"); // uri(0) should return base URI
        assertTrue(erc1155.hasRole(DEFAULT_ADMIN_ROLE, deployer), "Deployer should have admin role");
        assertTrue(erc1155.hasRole(MINTER_ROLE, deployer), "Deployer should have minter role");
    }

    // --- Test Minting ---
    function testMintSuccessAsMinter() public {
        vm.expectEmit(true, true, true, true); // Check TransferSingle event
        emit IERC1155.TransferSingle(deployer, address(0), deployer, TOKEN_ID_1, MINT_AMOUNT_1);

        erc1155.mint(deployer, TOKEN_ID_1, MINT_AMOUNT_1, "");

        assertEq(erc1155.balanceOf(deployer, TOKEN_ID_1), MINT_AMOUNT_1, "Mint amount mismatch");
    }

    function test_RevertWhen_MintingWithoutMinterRole() public {
        vm.startPrank(user);
        vm.expectRevert(_accessControlError(user, MINTER_ROLE));
        erc1155.mint(user, TOKEN_ID_1, MINT_AMOUNT_1, "");
        vm.stopPrank();
    }

    function test_RevertIf_MintingToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        erc1155.mint(address(0), TOKEN_ID_1, MINT_AMOUNT_1, "");
    }

    // --- Test Batch Minting ---
    function testMintBatchSuccessAsMinter() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = MINT_AMOUNT_1;
        amounts[1] = MINT_AMOUNT_2;

        vm.expectEmit(true, true, true, true);
        emit IERC1155.TransferBatch(deployer, address(0), deployer, ids, amounts);

        erc1155.mintBatch(deployer, ids, amounts, "");

        assertEq(erc1155.balanceOf(deployer, TOKEN_ID_1), MINT_AMOUNT_1, "Batch Mint amount 1 mismatch");
        assertEq(erc1155.balanceOf(deployer, TOKEN_ID_2), MINT_AMOUNT_2, "Batch Mint amount 2 mismatch");
    }

    function test_RevertWhen_MintingBatchWithoutMinterRole() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = MINT_AMOUNT_1;

        vm.startPrank(user);
        vm.expectRevert(_accessControlError(user, MINTER_ROLE));
        erc1155.mintBatch(user, ids, amounts, "");
        vm.stopPrank();
    }

    function test_RevertIf_MintingBatchToZeroAddress() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = TOKEN_ID_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = MINT_AMOUNT_1;

        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        erc1155.mintBatch(address(0), ids, amounts, "");
    }

    function test_RevertIf_MintingBatchWithMismatchedArrays() public {
        uint256[] memory ids = new uint256[](2); // Length 2
        ids[0] = TOKEN_ID_1;
        ids[1] = TOKEN_ID_2;
        uint256[] memory amounts = new uint256[](1); // Length 1
        amounts[0] = MINT_AMOUNT_1;

        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidArrayLength.selector, ids.length, amounts.length)
        );
        erc1155.mintBatch(deployer, ids, amounts, "");
    }

    // --- Test URI Update ---
    function testSetURISuccessAsAdmin() public {
        string memory newURI = "https://new.example.com/{id}";
        erc1155.setURI(newURI);
        assertEq(erc1155.uri(0), newURI, "URI not updated");
        assertEq(erc1155.uri(TOKEN_ID_1), newURI, "URI for ID 1 incorrect");
    }

    function test_RevertWhen_SettingURIWithoutAdminRole() public {
        string memory newURI = "https://new.example.com/";
        vm.startPrank(user);
        vm.expectRevert(_accessControlError(user, DEFAULT_ADMIN_ROLE));
        erc1155.setURI(newURI);
        vm.stopPrank();
    }

    // --- Test Role Management ---
    function testGrantRevokeMinterRole() public {
        // 1. Grant minter role to 'minter' address (by deployer/admin)
        erc1155.grantRole(MINTER_ROLE, minter);
        assertTrue(erc1155.hasRole(MINTER_ROLE, minter), "Minter role not granted");

        // 2. Verify 'minter' can now mint
        vm.startPrank(minter);
        erc1155.mint(minter, TOKEN_ID_1, MINT_AMOUNT_1, "");
        assertEq(erc1155.balanceOf(minter, TOKEN_ID_1), MINT_AMOUNT_1, "Mint by new minter failed");
        vm.stopPrank(); // Stop prank before admin action

        // 3. Revoke minter role from 'minter' address (by deployer/admin)
        erc1155.revokeRole(MINTER_ROLE, minter);
        assertFalse(erc1155.hasRole(MINTER_ROLE, minter), "Minter role not revoked");

        // 4. Verify 'minter' can no longer mint
        vm.startPrank(minter);
        vm.expectRevert(_accessControlError(minter, MINTER_ROLE));
        erc1155.mint(minter, TOKEN_ID_2, MINT_AMOUNT_2, "");
        vm.stopPrank();
    }

    function test_RevertWhen_GrantingRoleWithoutAdminRole() public {
        vm.startPrank(user); // User does not have DEFAULT_ADMIN_ROLE
        vm.expectRevert(_accessControlError(user, DEFAULT_ADMIN_ROLE));
        erc1155.grantRole(MINTER_ROLE, minter);
        vm.stopPrank();
    }

    // --- Test Interface Support (ERC165) ---
    function testSupportsInterface() public view {
        assertTrue(erc1155.supportsInterface(type(IERC165).interfaceId), "Does not support IERC165");
        assertTrue(erc1155.supportsInterface(type(IERC1155).interfaceId), "Does not support IERC1155");
        assertTrue(erc1155.supportsInterface(type(IAccessControl).interfaceId), "Does not support IAccessControl");
        assertTrue(erc1155.supportsInterface(type(IERC1155Mintable).interfaceId), "Does not support IERC1155Mintable");
        assertFalse(
            erc1155.supportsInterface(bytes4(keccak256("nonExistentInterface(uint256)"))),
            "Supports non-existent interface"
        );
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        virtual
        override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
