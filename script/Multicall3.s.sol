// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Multicall3} from "../src/Multicall3.sol";
import {console} from "forge-std/console.sol";

contract Multicall3Script is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        Multicall3 multicall = new Multicall3();
        console.log("Deployed Multicall3 at: %s", address(multicall));

        vm.stopBroadcast();
    }
}
