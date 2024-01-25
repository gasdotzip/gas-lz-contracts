// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/GasZipLZ.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run(address lzEndpoint) public {

        vm.startBroadcast();

        GasZipLZ gasZip = new GasZipLZ(lzEndpoint);
        vm.stopBroadcast();

        require(gasZip.owner() == msg.sender);
    }
}
