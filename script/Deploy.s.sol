// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MultisigCaller} from "../src/MultisigCaller.sol";
import {Lock} from "../src/Lock.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestContract is Ownable {
    uint256 public value;
    
    constructor() Ownable(msg.sender) {}
    
    function setValue(uint256 _value) public onlyOwner {
        value = _value;
    }
}

contract DeployScript is Script {
    function setUp() public {}

    function run(address[] memory _approvers) public {
        vm.startBroadcast();
        
        // Deploy test contracts that we'll transfer ownership of
        TestContract test1 = new TestContract();
        TestContract test2 = new TestContract();
        console.log("Deployed TestContract1 at: %s", address(test1));
        console.log("Deployed TestContract2 at: %s", address(test2));
        
        // Deploy MultisigCaller with approvers
        MultisigCaller multisig = new MultisigCaller(_approvers, 2);
        console.log("Deployed MultisigCaller at: %s", address(multisig));
        
        // Transfer ownership of test contracts to first approver
        test1.transferOwnership(address(multisig));
        test2.transferOwnership(address(multisig));
        
        vm.stopBroadcast();
    }
}
