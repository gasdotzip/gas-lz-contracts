// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./ILayerZeroEndpointV2.sol";
import "./IMessageLibManager.sol";
import "./IUlnBase.sol";

abstract contract OptimizedOApp is Ownable {
    ILayerZeroEndpointV2 public immutable endpoint;

    mapping(uint32 => bytes32) public peers;
    mapping(uint32 => uint128) public gasLimitLookup;

    uint128 public defaultGasLimit = 20_000;

    constructor(address _owner, address _endpoint) {
        endpoint = ILayerZeroEndpointV2(_endpoint);
        _initializeOwner(_owner);
        endpoint.setDelegate(_owner);
    }

    // Receive

    function nextNonce(uint32, bytes32) public pure virtual returns (uint64 nonce) {
        return 0;
    }

    function allowInitializePath(Origin calldata origin) public view virtual returns (bool) {
        return getPeer(origin.srcEid) == origin.sender;
    }

    function lzReceive(
        Origin calldata,
        bytes32,
        bytes calldata,
        address,
        bytes calldata
    ) external pure {
        return;
    }

    // Send

    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        uint _nativeFee,
        address _refundAddress
    ) internal virtual returns (MessagingReceipt memory receipt) {
        return endpoint.send{value: _nativeFee}(MessagingParams(_dstEid, getPeer(_dstEid), _message, _options, false), _refundAddress);
    }

    function getPeer(uint32 _dstEid) internal view returns (bytes32) {
        bytes32 trustedRemote = peers[_dstEid];
        if (trustedRemote == 0) {
            return bytes32(uint256(uint160(address(this))));
        } else {
            return trustedRemote;
        }
    }

    function getGasLimit(uint32 _dstEid) internal view returns (uint128) {
        uint128 gasLimit = gasLimitLookup[_dstEid];
        if (gasLimit == 0) {
            return defaultGasLimit;
        } else {
            return gasLimit;
        }
    }

    function setPeers(
        uint32[] calldata _remoteEids, 
        bytes32[] calldata _remoteAddresses
    ) external onlyOwner {
        require(_remoteEids.length == _remoteAddresses.length, "Length Mismatch");

        for (uint i; i < _remoteEids.length; i++) {
            peers[_remoteEids[i]] = _remoteAddresses[i];
        }
    }

    function setGasLimit(
        uint32[] calldata _remoteEids, 
        uint128[] calldata _gasLimits
    ) external onlyOwner {
        require(_remoteEids.length == _gasLimits.length, "Length Mismatch");

        for (uint i; i < _remoteEids.length; i++) {
            gasLimitLookup[_remoteEids[i]] = _gasLimits[i];
        }
    }

    function setDefaultGasLimit(uint128 _defaultGasLimit) external onlyOwner {
        defaultGasLimit = _defaultGasLimit;
    }

    function setDelegate(address _delegate) external onlyOwner {
        endpoint.setDelegate(_delegate);
    }

    function setUlnConfigs(address _lib, uint64 confirmations, uint32[] calldata eids, address dvn) external onlyOwner {
        SetConfigParam[] memory configs = new SetConfigParam[](eids.length);

        for(uint i; i < eids.length; i++) {
            address[] memory opt = new address[](0);
            address[] memory req = new address[](1);
            req[0] = dvn;

            bytes memory config = abi.encode(UlnConfig(confirmations, uint8(1), 0, 0, req, opt));
            configs[i] = SetConfigParam({eid: eids[i], configType: 2, config: config});
        }

        IMessageLibManager(address(endpoint)).setConfig(address(this), _lib, configs);
    }
}
