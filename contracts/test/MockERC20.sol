// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        address[] memory beneficiaries
    ) ERC20("Token", "TKN") {
        for (uint i = 0; i < beneficiaries.length; i++)
            _mint(beneficiaries[i], 100_000_000_000 * 10 ** decimals());
    }
}
