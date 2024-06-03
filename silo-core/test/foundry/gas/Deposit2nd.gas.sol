// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {Gas} from "./Gas.sol";

/*
forge test -vv --ffi --mt test_gas_ | grep -i '\[GAS\]'
*/
contract Deposit2ndGasTest is Gas, Test {
    function setUp() public {
        _gasTestsInit();

        vm.prank(BORROWER);
        silo0.deposit(ASSETS, BORROWER);
    }

    function test_gas_secondDeposit() public {
        _action(
            BORROWER,
            address(silo0),
            abi.encodeCall(ISilo.deposit, (ASSETS, BORROWER, ISilo.CollateralType.Collateral)),
            "Deposit2nd (no interest)",
            84304
        );
    }
}
