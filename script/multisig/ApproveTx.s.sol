// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MultisigCaller} from "../../src/MultisigCaller.sol";

contract ApproveTxScript is Script {
    function setUp() public {}

    function run(uint256 txId, address payable multisig) public {
        require(multisig != address(0), "Multisig address required");

        MultisigCaller multisigContract = MultisigCaller(multisig);

        vm.broadcast();
        multisigContract.approveTransaction(txId);

        (, , , bool executed, uint256 approvalCount) = multisigContract.transactions(txId);
        if (executed) {
            console.log("Transaction was executed!");
        } else {
            uint256 remaining = multisigContract.requiredApprovals() - approvalCount;
            console.log("Transaction was approved!");
            console.log(remaining, remaining == 1 ? "approval left." : "approvals left.");
        }
    }
}
