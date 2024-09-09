// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {SiloCoreDeployments, SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc SiloCoreDeploymentsTest
*/
contract SiloCoreDeploymentsTest is SiloLittleHelper, Test {
    function setUp() public {
        AddrLib.init();
    }

    /*
    forge test -vv --ffi --mt test_get_exists_
    */
    function test_get_exists_anvil() public {
        _setUpLocalFixture();

        address factoryFromSilo0 = address(silo0.factory());
        address factoryFromSilo1 = address(silo1.factory());
        address deployedFactory = SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, ChainsLib.ANVIL_ALIAS);

        assertEq(factoryFromSilo0, factoryFromSilo1, "factoryFromSilo0 == factoryFromSilo1");
        assertEq(factoryFromSilo0, deployedFactory, "factoryFromSilo0 == deployedFactory");
    }

    function test_get_exists_optimism() public {
        address addr = SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, ChainsLib.OPTIMISM_ALIAS);
        assertEq(addr, 0x01c6dc3bD8B175a9494F00b6D224b14EdC67CD34, "expect valid address Optimism");
    }

    function test_get_exists_arbitrum_one() public {
        address addr = SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, ChainsLib.ARBITRUM_ONE_ALIAS);
        assertEq(addr, 0x8C1b49B1A45d9FD50c5846a6Cd19a5ADaA376B1B, "expect valid address on Arbitrum");
    }

   function test_get_contractNotExists() public {
       address addr = SiloCoreDeployments.get("not.exist", ChainsLib.OPTIMISM_ALIAS);
       assertEq(addr, address(0), "expect to return 0");
   }

   function test_get_invalidNetwork() public {
       address addr = SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, "abcd");
       assertEq(addr, address(0), "expect to return 0");
   }
}
