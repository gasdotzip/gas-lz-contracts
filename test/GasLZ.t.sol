// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {GasZipLZ} from "../src/v1/GasZipLZ.sol";
import {LZEndpointMock} from "../src/v1/layerzero/mocks/LZEndpointMock.sol";

contract CounterTest is Test {

    GasZipLZ gasZip;

    function setUp() public {
        LZEndpointMock endpoint = new LZEndpointMock(10);
        LZEndpointMock endpoint2 = new LZEndpointMock(20);

        gasZip = new GasZipLZ(address(endpoint));
        GasZipLZ gasZip2 = new GasZipLZ(address(endpoint2));

        uint16[] memory ids = new uint16[](1);
        address[] memory addrs = new address[](1);
        ids[0] = 20;
        addrs[0] = address(gasZip2);
        gasZip.setTrusted(ids, addrs);

        ids[0] = 10;
        addrs[0] = address(gasZip);
        gasZip2.setTrusted(ids, addrs);

        endpoint.setDestLzEndpoint(address(gasZip), address(endpoint));
        endpoint.setDestLzEndpoint(address(gasZip2), address(endpoint2));
    }

    function testDeposit() public {

        uint nativeAmount = 1e18;
        address to = address(this);

        bytes memory adapter = gasZip.createAdapterParams(20, nativeAmount, to);

        uint[] memory adapters = new uint[](2);
        adapters[0] = uint256((20 << 240) | nativeAmount);

        adapters[1] = uint256((10 << 240) | nativeAmount);

        uint v = gasZip.estimateFees(20, adapter);
        gasZip.deposit{value: v*2}(adapters, to);
    }

    receive() external payable {}
}
