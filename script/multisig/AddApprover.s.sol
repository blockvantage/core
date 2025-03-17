// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {MultisigCaller} from "../../src/MultisigCaller.sol";
import {MultisigScript} from "./MultisigScript.sol";

contract AddApproverScript is MultisigScript {
    function setUp() public {}

    function run(address newApprover, address payable multisig) public {
        require(multisig != address(0), "Multisig address required");
        
        MultisigCaller multisigContract = MultisigCaller(multisig);
        bytes32 approverRole = multisigContract.APPROVER_ROLE();
        bytes memory grantRoleCall = abi.encodeWithSignature("grantRole(bytes32,address)", approverRole, newApprover);
        
        vm.startBroadcast();
        vm.recordLogs();
        multisigContract.submitTransaction(multisig, 0, grantRoleCall);
        uint256 txId = getTransactionId();
        console.log("Add approver transaction submitted!");
        console.log("Transaction ID: %d", txId);
        vm.stopBroadcast();
    }
}
