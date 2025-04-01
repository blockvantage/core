// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {MultisigScript} from "./MultisigScript.sol";
import {MultisigCaller} from "../../src/MultisigCaller.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TransferOwnershipBatchScript is MultisigScript {
    function setUp() public {}

    function run(address[] calldata addresses, address newMultisig) public {
        require(addresses.length > 0, "No addresses provided");

        // Get the first contract's owner to use as old multisig
        address payable oldMultisig = payable(Ownable(addresses[0]).owner());
        console.log("Current owner (from %s): %s", addresses[0], oldMultisig);

        MultisigCaller oldMultisigContract = MultisigCaller(oldMultisig);

        // Create batch calls for transferring ownership
        MultisigCaller.Call3[] memory calls = new MultisigCaller.Call3[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            calls[i] = MultisigCaller.Call3({
                target: addresses[i],
                allowFailure: false,
                callData: abi.encodeWithSignature("transferOwnership(address)", newMultisig)
            });
        }

        vm.startBroadcast();
        bytes memory aggregateCall = abi.encodeWithSignature("aggregate3((address,bool,bytes)[])", calls);
        uint256 txId = oldMultisigContract.submitTransaction(oldMultisig, 0, aggregateCall);
        console.log("Transaction submitted!");
        console.log("Transaction ID: %d", txId);
        vm.stopBroadcast();
    }
}
