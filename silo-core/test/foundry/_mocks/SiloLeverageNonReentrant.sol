// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Silo, ILeverageBorrower, ISiloFactory, ISiloConfig} from "silo-core/contracts/Silo.sol";
import {CrossEntrancy} from "silo-core/contracts/lib/CrossEntrancy.sol";

contract SiloLeverageNonReentrant is Silo {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {}

    function leverage(uint256, ILeverageBorrower, address, bool, bytes calldata)
        external
        override
        returns (uint256 shares)
    {
//        Silo(address(this)).config().crossNonReentrantBefore(CrossEntrancy.ENTERED_FROM_LEVERAGE); TODO
        shares = 0;

        // Inputs don't matter. We only need to verify reentrancy protection.
        // Expect to revert with `ISiloConfig.CrossReentrantCall.selector`
        Silo(address(this)).borrow({_assets: 1, _borrower: address(0), _receiver: address(0), _sameAsset: false});

//        Silo(address(this)).config().crossNonReentrantAfter();  TODO
    }

    function forceConfigSetup(ISiloConfig _siloConfig) external {
        sharedStorage.siloConfig = _siloConfig;
    }
}
