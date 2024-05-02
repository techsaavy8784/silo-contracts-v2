// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// solhint-disable private-vars-leading-underscore
library Hook {
    uint256 internal constant NONE = 0;
    uint256 internal constant SAME_ASSET = 2 ** 1;
    uint256 internal constant TWO_ASSETS = 2 ** 2;
    uint256 internal constant BEFORE = 2 ** 3;
    uint256 internal constant AFTER = 2 ** 4;
    uint256 internal constant DEPOSIT = 2 ** 5;
    uint256 internal constant BORROW = 2 ** 6;
    uint256 internal constant REPAY = 2 ** 7;
    uint256 internal constant WITHDRAW = 2 ** 8;
    uint256 internal constant LEVERAGE = 2 ** 9;
    uint256 internal constant FLASH_LOAN = 2 ** 10;
    uint256 internal constant TRANSITION_COLLATERAL = 2 ** 11;
    uint256 internal constant SWITCH_COLLATERAL = 2 ** 12;
    uint256 internal constant LIQUIDATION = 2 ** 13;
    uint256 internal constant SHARE_TOKEN_TRANSFER = 2 ** 14;
    uint256 internal constant COLLATERAL_TOKEN = 2 ** 15;
    uint256 internal constant PROTECTED_TOKEN = 2 ** 16;
    uint256 internal constant DEBT_TOKEN = 2 ** 17;

    // note: currently we can support hook value up to 2 ** 23,
    // because for optimisation purposes, we storing hooks as uint24

    function matchAction(uint256 _action, uint256 _expectedHook) internal pure returns (bool) {
        return _action & _expectedHook == _expectedHook;
    }

    function addAction(uint256 _action, uint256 _newAction) internal pure returns (uint256) {
        return _action | _newAction;
    }

    /// @dev please be careful with removing actions, because other hooks might using them
    /// eg when you have `_action = COLLATERAL_TOKEN | PROTECTED_TOKEN | SHARE_TOKEN_TRANSFER`
    /// and you want to remove action on protected token transfer by doing
    /// `remove(_action, PROTECTED_TOKEN | SHARE_TOKEN_TRANSFER)`, the result will be `_action=COLLATERAL_TOKEN`
    /// and it will not trigger collateral token transfer. In this example you should do:
    /// `remove(_action, PROTECTED_TOKEN)`
    function removeAction(uint256 _action, uint256 _actionToRemove) internal pure returns (uint256) {
        return _action & (~_actionToRemove);
    }
}
