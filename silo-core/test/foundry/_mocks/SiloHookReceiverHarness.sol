// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SiloHookReceiver} from "silo-core/contracts/utils/hook-receivers/_common/SiloHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

contract SiloHookReceiverHarness is SiloHookReceiver {
    function setHookConfig(address _silo, uint256 _hooksBefore, uint256 _hooksAfter) external virtual {
        _setHookConfig(_silo, _hooksBefore, _hooksAfter);
    }

    function afterAction(address _silo, uint256 _action, bytes calldata _inputAndOutput) external virtual {}

    function beforeAction(address _silo, uint256 _action, bytes calldata _input) external virtual {}

    function initialize(ISiloConfig _siloConfig, bytes calldata _data) external virtual {}

    function hookReceiverConfig(address _silo) external view virtual returns (uint24 hooksBefore, uint24 hooksAfter) {
        (hooksBefore, hooksAfter) = _hookReceiverConfig(_silo);
    }

    function getHooksBefore(address _silo) external view virtual returns (uint256 hooksBefore) {
        hooksBefore = _getHooksBefore(_silo);
    }

    function getHooksAfter(address _silo) external view virtual returns (uint256 hooksAfter) {
        hooksAfter = _getHooksAfter(_silo);
    }
}
