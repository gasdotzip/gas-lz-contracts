// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OptimizedOApp.sol";

contract GasLZV2 is OptimizedOApp {

    constructor(address _owner, address _endpoint) OptimizedOApp(_owner, _endpoint) {}

    event SentMessages(uint32[] eids, bytes[] messages, uint value, uint fee, address from);
    event SentDeposits(uint256[] params, address to, uint value, uint fee, address from);

    function sendMessages(
        uint32[] calldata _dstEids,
        bytes[] calldata _messages
    ) external payable {
        uint256 fee;
        for (uint i; i < _messages.length; i++) {
            fee += _sendMessage(_dstEids[i], _messages[i]);
        }
        require(msg.value >= fee, "Fee Not Met");
        emit SentMessages(_dstEids, _messages, msg.value, fee, msg.sender);
    }

    function sendDeposits(
        uint256[] calldata _depositParams,
        address _to
    ) external payable {
        uint256 fee;
        for (uint i; i < _depositParams.length; i++) {
            fee += _sendDeposit(uint32(_depositParams[i] >> 224), uint128(_depositParams[i]), _to);
        }
        require(msg.value >= fee, "Fee Not Met");
        emit SentDeposits(_depositParams, _to, msg.value, fee, msg.sender);
    }

    function _sendMessage(uint32 _dstEid, bytes calldata _message) internal returns (uint256 fee) {
        MessagingReceipt memory receipt = _lzSend(_dstEid, _message, createReceiveOption(_dstEid), address(this).balance, address(this));
        return receipt.fee.nativeFee;
    }

    function _sendDeposit(uint32 _dstEid, uint128 _amount, address _to) internal returns (uint256 fee) {
        MessagingReceipt memory receipt = _lzSend(_dstEid, "", createNativeDropOption(_dstEid, _amount, _to), address(this).balance, address(this));
        return receipt.fee.nativeFee;
    }

    function createReceiveOption(uint32 _dstEid) public view returns (bytes memory) {
        return abi.encodePacked(
            abi.encodePacked(uint16(3)),
            uint8(1),
            uint16(16+1),
            uint8(1),
            abi.encodePacked(getGasLimit(_dstEid))
        );
    }

    function createNativeDropOption(uint32 _dstEid, uint128 _nativeAmount, address _to) public view returns (bytes memory) {
        return abi.encodePacked(
            createReceiveOption(_dstEid),
            uint8(1),
            uint16(32+16+1),
            uint8(2),
            abi.encodePacked(_nativeAmount, bytes32(uint256(uint160(_to))))
        );
    }

    function estimateFees(
        uint32[] calldata _dstEids,
        bytes[] calldata _messages,
        bytes[] calldata _options
    ) external view returns (uint256[] memory nativeFees) {
        nativeFees = new uint256[](_dstEids.length);
        for (uint i; i < _dstEids.length; i++) {
            nativeFees[i] = quote(_dstEids[i], _messages[i], _options[i]);
        }
    }

    function quote(uint32 _dstEid, bytes calldata _message, bytes memory _options) public view returns (uint256 nativeFee) {
        MessagingFee memory fee = endpoint.quote(MessagingParams(_dstEid, getPeer(_dstEid), _message, _options, false), address(this));
        return fee.nativeFee;
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        bool s;
        if (token == address(0)) {
            (s,) = msg.sender.call{value: address(this).balance}("");
        } else {
            (s,) = token.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount));
        }
        require(s, "Withdraw Failed");
    }

    receive() external payable {}
}
