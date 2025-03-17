// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {MultisigCaller} from "../../src/MultisigCaller.sol";

abstract contract MultisigScript is Script {
    function getTransactionId() internal returns (uint256) {
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            // Check if this is the TransactionSubmitted event
            if (entries[i].topics[0] == keccak256("TransactionSubmitted(uint256,address,uint256,bytes)")) {
                return uint256(entries[i].topics[1]);
            }
        }
        revert("Transaction ID not found in logs");
    }
}
