// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {KeyValueStorage as KV} from "silo-foundry-utils/key-value/KeyValueStorage.sol";

import {ChildChainGaugeDeployer} from "./ChildChainGaugeDeployer.s.sol";

library ChildChainGaugeConfigsParser {
    string constant public CONFIGS_DIR = "ve-silo/deploy/gauges/child-chain-gauge/configs/";
    string constant internal _EXTENSION = ".json";

    function getConfig(
        string memory _network,
        string memory _name
    )
        internal
        returns (ChildChainGaugeDeployer.ChildChainGaugeDeploymentConfig memory config)
    {
        string memory configJson = configFile(_network);

        config.silo = KV.getString(configJson, _name, "silo");
        config.asset = KV.getString(configJson, _name, "asset");
        config.token = KV.getString(configJson, _name, "token");
    }

    function configFile(string memory _network) internal view returns (string memory file) {
        file = string.concat(CONFIGS_DIR, _network, _EXTENSION);
    }
}
