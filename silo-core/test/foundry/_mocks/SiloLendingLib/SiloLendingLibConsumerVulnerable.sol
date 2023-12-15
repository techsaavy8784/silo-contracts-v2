// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLendingLibWithReentrancyIssue} from "./SiloLendingLibWithReentrancyIssue.sol";

contract SiloLendingLibConsumerVulnerable {
    uint256 public constant INITIAL_TOTAL = 100;

    mapping(ISilo.AssetType => ISilo.Assets) internal _total;

    constructor() {
        _total[ISilo.AssetType.Debt].assets = INITIAL_TOTAL;
    }

    function repay(
        ISiloConfig.ConfigData memory _configData,
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer
    ) external {
        SiloLendingLibWithReentrancyIssue.repay(
            _configData,
            _assets,
            _shares,
            _borrower,
            _repayer,
            _total[ISilo.AssetType.Debt]
        );
    }

    function getTotalDebt() public view returns (uint256) {
        return _total[ISilo.AssetType.Debt].assets;
    }
}
