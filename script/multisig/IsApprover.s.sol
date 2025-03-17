// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MultisigCaller} from "../../src/MultisigCaller.sol";

contract IsApproverScript is Script {
    function setUp() public {}

    function run(address account, address payable multisig) public view returns (bool) {
        require(multisig != address(0), "Multisig address required");

        MultisigCaller multisigContract = MultisigCaller(multisig);
        bool isApprover = multisigContract.hasRole(multisigContract.APPROVER_ROLE(), account);

        console.log("Account %s is%s an approver", account, isApprover ? "" : " not");
        return isApprover;
    }
}
