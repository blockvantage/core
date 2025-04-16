// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title IERC1155Mintable Interface
 * @dev Interface for an ERC1155 token contract with minting capabilities controlled by AccessControl.
 */
interface IERC1155Mintable {
    /**
     * @dev Sets the base URI for the token metadata.
     * Requires the caller to have the necessary administrative role (e.g., DEFAULT_ADMIN_ROLE).
     * @param newuri The new base URI.
     */
    function setURI(string memory newuri) external;

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     * Requires the caller to have the necessary minter role (e.g., MINTER_ROLE).
     * Emits a {TransferSingle} event.
     * Requirements:
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * correct magic value.
     * @param to The address that will receive the tokens.
     * @param id The token type ID.
     * @param amount The amount of tokens to mint.
     * @param data Additional data with no specified format.
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external;

    /**
     * @dev Batched version of {mint}.
     * Requires the caller to have the necessary minter role (e.g., MINTER_ROLE).
     * Emits a {TransferBatch} event.
     * Requirements:
     * - `ids` and `amounts` must have the same length.
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * correct magic value.
     * @param to The address that will receive the tokens.
     * @param ids The token type IDs.
     * @param amounts The amounts of tokens to mint.
     * @param data Additional data with no specified format.
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;
}
