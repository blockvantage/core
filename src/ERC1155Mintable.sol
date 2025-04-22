// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC1155Mintable} from "./interfaces/IERC1155Mintable.sol";

/**
 * @title ERC1155Mintable
 * @dev ERC1155 token contract with minting capabilities controlled by AccessControl.
 * The admin address is granted both the DEFAULT_ADMIN_ROLE and MINTER_ROLE.
 * @notice Implements IERC1155Mintable interface.
 */
contract ERC1155Mintable is Context, AccessControlEnumerable, ERC1155, IERC1155Mintable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Constructor that sets the base URI and grants roles to the specified admin.
     * @param uri_ The base URI for the token metadata.
     * @param admin The address to grant admin and minter roles to.
     */
    constructor(string memory uri_, address admin) ERC1155(uri_) {
        if (admin == address(0)) revert ERC1155MintableZeroAddressAdmin();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    /**
     * @inheritdoc IERC1155Mintable
     */
    function setURI(string calldata newuri) external virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
    }

    /**
     * @inheritdoc IERC1155Mintable
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        override
        onlyRole(MINTER_ROLE)
    {
        _mint(to, id, amount, data);
    }

    /**
     * @inheritdoc IERC1155Mintable
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external
        virtual
        override
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC1155)
        returns (bool)
    {
        return interfaceId == type(IERC1155Mintable).interfaceId || super.supportsInterface(interfaceId);
    }
}
