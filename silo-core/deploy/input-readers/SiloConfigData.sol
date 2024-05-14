// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {OraclesDeployments} from "silo-oracles/deploy/OraclesDeployments.sol";
import {CommonDeploy, SiloCoreContracts} from "../_CommonDeploy.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

contract SiloConfigData is Test, CommonDeploy {
    uint256 constant BP2DP_NORMALIZATION = 10 ** (18 - 4);

    bytes32 public constant NO_ORACLE_KEY = keccak256(bytes("NO_ORACLE"));
    bytes32 public constant PLACEHOLDER_KEY = keccak256(bytes("PLACEHOLDER"));
    bytes32 public constant NO_HOOK_RECEIVER_KEY = keccak256(bytes("NO_HOOK_RECEIVER"));

    error HookReceiverImplNotFound(string hookReceiver);

    // must be in alphabetic order
    struct ConfigData {
        bool callBeforeQuote0;
        bool callBeforeQuote1;
        address deployer;
        uint256 deployerFee;
        uint64 flashloanFee0;
        uint64 flashloanFee1;
        string hookReceiver;
        string hookReceiverImplementation;
        address interestRateModel0;
        address interestRateModel1;
        string interestRateModelConfig0;
        string interestRateModelConfig1;
        uint64 liquidationFee0;
        uint64 liquidationFee1;
        address liquidationModule;
        uint64 lt0;
        uint64 lt1;
        uint64 maxLtv0;
        uint64 maxLtv1;
        string maxLtvOracle0;
        string maxLtvOracle1;
        string solvencyOracle0;
        string solvencyOracle1;
        string token0;
        string token1;
    }

    function _readInput(string memory _input) internal view returns (string memory data) {
        string memory inputDir = string.concat(vm.projectRoot(), "/silo-core/deploy/input/");
        string memory chainDir = string.concat(ChainsLib.chainAlias(block.chainid), "/");
        string memory file = string.concat(_input, ".json");

        console2.log("reading from %s", string.concat(inputDir, chainDir, file));
        data = vm.readFile(string.concat(inputDir, chainDir, file));
        console2.log("reading successful, read bytes: %s", bytes(data).length);
    }

    function _readDataFromJson(string memory _name) internal view returns (ConfigData memory) {
        return abi.decode(vm.parseJson(_readInput(_name), string(abi.encodePacked("."))), (ConfigData));
    }

    function getConfigData(string memory _name)
        public
        returns (ConfigData memory config, ISiloConfig.InitData memory initData, address _hookReceiverImplementation)
    {
        config = _readDataFromJson(_name);
        _hookReceiverImplementation = _resolveHookReceiverImpl(config.hookReceiverImplementation);

        initData = ISiloConfig.InitData({
            deployer: config.deployer,
            liquidationModule: config.liquidationModule,
            hookReceiver: _resolveHookReceiverImpl(config.hookReceiver),
            deployerFee: config.deployerFee * BP2DP_NORMALIZATION,
            token0: getAddress(config.token0),
            solvencyOracle0: address(0),
            maxLtvOracle0: address(0),
            interestRateModel0: address(0),
            interestRateModelConfig0: address(0),
            maxLtv0: config.maxLtv0 * BP2DP_NORMALIZATION,
            lt0: config.lt0 * BP2DP_NORMALIZATION,
            liquidationFee0: config.liquidationFee0 * BP2DP_NORMALIZATION,
            flashloanFee0: config.flashloanFee0 * BP2DP_NORMALIZATION,
            callBeforeQuote0: config.callBeforeQuote0,
            token1: getAddress(config.token1),
            solvencyOracle1: address(0),
            maxLtvOracle1: address(0),
            interestRateModel1: address(0),
            interestRateModelConfig1: address(0),
            maxLtv1: config.maxLtv1 * BP2DP_NORMALIZATION,
            lt1: config.lt1 * BP2DP_NORMALIZATION,
            liquidationFee1: config.liquidationFee1 * BP2DP_NORMALIZATION,
            flashloanFee1: config.flashloanFee1 * BP2DP_NORMALIZATION,
            callBeforeQuote1: config.callBeforeQuote1
        });
    }

    function _resolveHookReceiverImpl(string memory _requiredHookReceiver) internal returns (address hookReceiver) {
        if (keccak256(bytes(_requiredHookReceiver)) != NO_HOOK_RECEIVER_KEY) {
            hookReceiver = getDeployedAddress(_requiredHookReceiver);
            if (hookReceiver == address(0)) revert HookReceiverImplNotFound(_requiredHookReceiver);
        }
    }
}
