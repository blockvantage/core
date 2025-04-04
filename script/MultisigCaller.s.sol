// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MultisigCaller} from "../src/MultisigCaller.sol";
import {strings} from "solidity-stringutils/strings.sol";

contract MultisigCallerScript is Script {
    MultisigCaller public multisig;
    using strings for *;

    function setUp() public {}

    function run() public {
        string memory approversStr = vm.envString("APPROVERS");
        uint256 requiredApprovals = vm.envUint("REQUIRED_APPROVALS");
        
        address[] memory approvers = _parseAddresses(approversStr);
        this.run(approvers, requiredApprovals);
    }

    function _parseAddresses(string memory str) internal pure returns (address[] memory) {
        strings.slice memory s = str.toSlice();
        strings.slice memory delim = ",".toSlice();
        address[] memory result = new address[](s.count(delim) + 1);
        
        for(uint i = 0; i < result.length; i++) {
            result[i] = vm.parseAddress(s.split(delim).toString());
        }
        return result;
    }

    function run(address[] memory approvers, uint256 requiredApprovals) public {
        vm.startBroadcast();

        multisig = new MultisigCaller(approvers, requiredApprovals);
        console.log("Deployed MultisigCaller at: %s", address(multisig));

        vm.stopBroadcast();
    }
}