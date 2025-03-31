// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OwnableTest is Ownable {
    constructor() Ownable(msg.sender) {}

    function restrictedFunction() external view onlyOwner returns (bool) {
        return true;
    }
}
