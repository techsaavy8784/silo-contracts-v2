// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {Gas} from "./Gas.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]'
*/
contract Deposit2ndGasTest is Gas, Test {
    constructor() Gas(vm) {}

    function setUp() public {
        _gasTestsInit();

        vm.prank(BORROWER);
        silo0.deposit(ASSETS, BORROWER);
    }

    function test_gas_secondDeposit() public {
        _action(
            BORROWER,
            silo0,
            abi.encodeCall(ISilo.deposit, (ASSETS, BORROWER, ISilo.AssetType.Collateral)),
            "2nd deposit (no interest)",
            96447
        );
    }
}
