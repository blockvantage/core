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

        console.log("Transaction approved!");
    }
}
