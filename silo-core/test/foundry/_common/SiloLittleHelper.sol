// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {MintableToken} from "./MintableToken.sol";
import {SiloFixture, SiloConfigOverride} from "./fixtures/SiloFixture.sol";
import {LocalVm} from "./LocalVm.sol";

abstract contract SiloLittleHelper is LocalVm {
    MintableToken token0;
    MintableToken token1;

    ISilo silo0;
    ISilo silo1;

    function __init(MintableToken _token0, MintableToken _token1, ISilo _silo0, ISilo _silo1) internal {
        token0 = _token0;
        token1 = _token1;
        silo0 = _silo0;
        silo1 = _silo1;
    }

    function _setUpLocalFixture() internal returns (ISiloConfig siloConfig) {
        return _localFixture("");
    }

    function _setUpLocalFixture(string memory _configName) internal returns (ISiloConfig siloConfig) {
        return _localFixture(_configName);
    }

    function _depositForBorrow(uint256 _assets, address _depositor) internal returns (uint256 shares) {
        return _makeDeposit(silo1, token1, _assets, _depositor, ISilo.AssetType.Collateral);
    }

    function _deposit(uint256 _assets, address _depositor, ISilo.AssetType _type) internal returns (uint256 shares) {
        return _makeDeposit(silo0, token0, _assets, _depositor, _type);
    }

    function _deposit(uint256 _assets, address _depositor) internal returns (uint256 shares) {
        return _makeDeposit(silo0, token0, _assets, _depositor, ISilo.AssetType.Collateral);
    }

    function _borrow(uint256 _amount, address _borrower) internal returns (uint256 shares) {
        _vm.prank(_borrower);
        shares = silo1.borrow(_amount, _borrower, _borrower);
    }

    function _repay(uint256 _amount, address _borrower) internal returns (uint256 shares) {
        _mintTokens(token1, _amount, _borrower);
        _vm.prank(_borrower);
        token1.approve(address(silo1), _amount);
        _vm.prank(_borrower);

        shares = silo1.repay(_amount, _borrower);
    }

    function _repayShares(uint256 _approval, uint256 _shares, address _borrower)
        internal
        returns (uint256 shares)
    {
        return _repayShares(_approval, _shares, _borrower, bytes(""));
    }

    function _repayShares(uint256 _approval, uint256 _shares, address _borrower, bytes memory _revert)
        internal
        returns (uint256 shares)
    {
        _mintTokens(token1, _approval, _borrower);
        _vm.prank(_borrower);
        token1.approve(address(silo1), _approval);
        _vm.prank(_borrower);

        if (_revert.length != 0) {
            _vm.expectRevert(_revert);
        }

        shares = silo1.repayShares(_shares, _borrower);
    }

    function _withdraw(uint256 _amount, address _depositor) internal returns (uint256 assets){
        _vm.prank(_depositor);
        return silo0.withdraw(_amount, _depositor, _depositor);
    }

    function _withdraw(uint256 _amount, address _depositor, ISilo.AssetType _type) internal returns (uint256 assets){
        _vm.prank(_depositor);
        return silo0.withdraw(_amount, _depositor, _depositor, _type);
    }

    function _makeDeposit(ISilo _silo, MintableToken _token, uint256 _assets, address _depositor, ISilo.AssetType _type)
        internal
        returns (uint256 shares)
    {
        _mintTokens(_token, _assets, _depositor);

        _vm.startPrank(_depositor);
        _token.approve(address(_silo), _assets);
        shares = _silo.deposit(_assets, _depositor, _type);
        _vm.stopPrank();

    }

    function _mintTokens(MintableToken _token, uint256 _assets, address _user) internal {
        uint256 balanceOf = _token.balanceOf(_user);

        if (balanceOf < _assets) {
            uint256 toMint = _assets - balanceOf;
            _token.mint(_user, toMint);
        }
    }

    function _createDebt(uint256 _amount, address _borrower) internal returns (uint256 debtShares){
        _depositForBorrow(_amount, address(0x987654321));
        _deposit(_amount * 2, _borrower);
        debtShares = _borrow(_amount, _borrower);
    }

    function _localFixture(string memory _configName)
        private
        returns (ISiloConfig siloConfig)
    {
        token0 = new MintableToken();
        token1 = new MintableToken();

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.configName = _configName;

        SiloFixture siloFixture = new SiloFixture();
        (siloConfig, silo0, silo1,,) = siloFixture.deploy_local(overrides);
    }
}
