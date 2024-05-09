// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {SiloLensLib} from "../lib/SiloLensLib.sol";
import {IShareToken, ShareToken, ISilo} from "./ShareToken.sol";

/// @title ShareCollateralToken
/// @notice ERC20 compatible token representing collateral in Silo
/// @custom:security-contact security@silo.finance
contract ShareCollateralToken is ShareToken {
    using SiloLensLib for ISilo;

    /// @param _silo Silo address for which tokens was deployed
    function initialize(ISilo _silo) external virtual initializer {
        __ShareToken_init(_silo);
    }

    /// @inheritdoc IShareToken
    function mint(address _owner, address, uint256 _amount) external virtual override onlySilo {
        _mint(_owner, _amount);
    }

    /// @inheritdoc IShareToken
    function burn(address _owner, address _spender, uint256 _amount) external virtual onlySilo {
        if (_owner != _spender) _spendAllowance(_owner, _spender, _amount);
        _burn(_owner, _amount);
    }

    /// @dev Check if sender is solvent after the transfer
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        // for minting or burning, Silo is responsible to check all necessary conditions
        // for transfer make sure that _sender is solvent after transfer
        if (_isTransfer(_sender, _recipient)) {
            _callOracleBeforeQuote(_sender);
            if (!silo.isSolvent(_sender)) revert SenderNotSolventAfterTransfer();
        }

        ShareToken._afterTokenTransfer(_sender, _recipient, _amount);
    }
}
