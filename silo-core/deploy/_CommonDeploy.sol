// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";

import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";

contract CommonDeploy is Deployer {
    // Common variables
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/silo-core";

    error UnsopportedNetworkForDeploy(string networkAlias);

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return SiloCoreDeployments.DEPLOYMENTS_DIR;
    }
}
