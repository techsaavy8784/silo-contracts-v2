// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo} from "./interfaces/ISilo.sol";
import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {CrossReentrancyGuard} from "./utils/CrossReentrancyGuard.sol";
import {Hook} from "./lib/Hook.sol";

// solhint-disable var-name-mixedcase

/// @notice SiloConfig stores full configuration of Silo in immutable manner
/// @dev Immutable contract is more expensive to deploy than minimal proxy however it provides nearly 10x cheapper
/// data access using immutable variables.
contract SiloConfig is ISiloConfig, CrossReentrancyGuard {
    using Hook for uint256;
    
    uint256 public immutable SILO_ID;

    uint256 private immutable _DAO_FEE;
    uint256 private immutable _DEPLOYER_FEE;
    address private immutable _HOOK_RECEIVER;

    // TOKEN #0

    address private immutable _SILO0;

    address private immutable _TOKEN0;

    /// @dev Token that represents a share in total protected deposits of Silo
    address private immutable _PROTECTED_COLLATERAL_SHARE_TOKEN0;
    /// @dev Token that represents a share in total deposits of Silo
    address private immutable _COLLATERAL_SHARE_TOKEN0;
    /// @dev Token that represents a share in total debt of Silo
    address private immutable _DEBT_SHARE_TOKEN0;

    address private immutable _SOLVENCY_ORACLE0;
    address private immutable _MAX_LTV_ORACLE0;

    address private immutable _INTEREST_RATE_MODEL0;

    uint256 private immutable _MAX_LTV0;
    uint256 private immutable _LT0;
    uint256 private immutable _LIQUIDATION_FEE0;
    uint256 private immutable _FLASHLOAN_FEE0;

    bool private immutable _CALL_BEFORE_QUOTE0;

    // TOKEN #1

    address private immutable _SILO1;

    address private immutable _TOKEN1;

    /// @dev Token that represents a share in total protected deposits of Silo
    address private immutable _PROTECTED_COLLATERAL_SHARE_TOKEN1;
    /// @dev Token that represents a share in total deposits of Silo
    address private immutable _COLLATERAL_SHARE_TOKEN1;
    /// @dev Token that represents a share in total debt of Silo
    address private immutable _DEBT_SHARE_TOKEN1;

    address private immutable _SOLVENCY_ORACLE1;
    address private immutable _MAX_LTV_ORACLE1;

    address private immutable _INTEREST_RATE_MODEL1;

    uint256 private immutable _MAX_LTV1;
    uint256 private immutable _LT1;
    uint256 private immutable _LIQUIDATION_FEE1;
    uint256 private immutable _FLASHLOAN_FEE1;

    bool private immutable _CALL_BEFORE_QUOTE1;

    mapping (address borrower => address collateralSilo) internal _borrowerCollateralSilo;
    
    /// @param _siloId ID of this pool assigned by factory
    /// @param _configData0 silo configuration data for token0
    /// @param _configData1 silo configuration data for token1
    constructor( // solhint-disable-line function-max-lines
        uint256 _siloId,
        ConfigData memory _configData0,
        ConfigData memory _configData1
    ) CrossReentrancyGuard() {
        SILO_ID = _siloId;

        // To make further computations in the Silo secure require DAO and deployer fees to be less than 100%
        if (_configData0.daoFee + _configData0.deployerFee >= 1e18) revert FeeTooHigh();

        _DAO_FEE = _configData0.daoFee;
        _DEPLOYER_FEE = _configData0.deployerFee;
        _HOOK_RECEIVER = _configData0.hookReceiver;

        // TOKEN #0

        _SILO0 = _configData0.silo;
        _TOKEN0 = _configData0.token;

        _PROTECTED_COLLATERAL_SHARE_TOKEN0 = _configData0.protectedShareToken;
        _COLLATERAL_SHARE_TOKEN0 = _configData0.collateralShareToken;
        _DEBT_SHARE_TOKEN0 = _configData0.debtShareToken;

        _SOLVENCY_ORACLE0 = _configData0.solvencyOracle;
        _MAX_LTV_ORACLE0 = _configData0.maxLtvOracle;

        _INTEREST_RATE_MODEL0 = _configData0.interestRateModel;

        _MAX_LTV0 = _configData0.maxLtv;
        _LT0 = _configData0.lt;
        _LIQUIDATION_FEE0 = _configData0.liquidationFee;
        _FLASHLOAN_FEE0 = _configData0.flashloanFee;

        _CALL_BEFORE_QUOTE0 = _configData0.callBeforeQuote;

        // TOKEN #1

        _SILO1 = _configData1.silo;
        _TOKEN1 = _configData1.token;

        _PROTECTED_COLLATERAL_SHARE_TOKEN1 = _configData1.protectedShareToken;
        _COLLATERAL_SHARE_TOKEN1 = _configData1.collateralShareToken;
        _DEBT_SHARE_TOKEN1 = _configData1.debtShareToken;

        _SOLVENCY_ORACLE1 = _configData1.solvencyOracle;
        _MAX_LTV_ORACLE1 = _configData1.maxLtvOracle;

        _INTEREST_RATE_MODEL1 = _configData1.interestRateModel;

        _MAX_LTV1 = _configData1.maxLtv;
        _LT1 = _configData1.lt;
        _LIQUIDATION_FEE1 = _configData1.liquidationFee;
        _FLASHLOAN_FEE1 = _configData1.flashloanFee;

        _CALL_BEFORE_QUOTE1 = _configData1.callBeforeQuote;
    }

    /// @inheritdoc ISiloConfig
    function setThisSiloAsCollateralSilo(address _borrower) external virtual {
        _onlySilo();
        _borrowerCollateralSilo[_borrower] = msg.sender == _SILO0 ? _SILO0 : _SILO1;
    }

    /// @inheritdoc ISiloConfig
    function setOtherSiloAsCollateralSilo(address _borrower) external virtual {
        _onlySilo();
        _borrowerCollateralSilo[_borrower] = msg.sender == _SILO0 ? _SILO1 : _SILO0;
    }

    /// @inheritdoc ISiloConfig
    function switchCollateralSilo(address _borrower) external virtual {
        _onlySilo();

        address debtSilo = getDebtSilo(_borrower);

        if (debtSilo == address(0)) revert NoDebt();

        address currentSilo = _borrowerCollateralSilo[_borrower];

        _borrowerCollateralSilo[_borrower] = currentSilo == _SILO0 ? _SILO1 : _SILO0;
    }

    /// @inheritdoc ISiloConfig
    function onDebtTransfer(address _sender, address _recipient) external virtual {
        if (msg.sender != _DEBT_SHARE_TOKEN0 && msg.sender != _DEBT_SHARE_TOKEN1) revert OnlyDebtShareToken();

        address thisSilo = msg.sender == _DEBT_SHARE_TOKEN0 ? _SILO0 : _SILO1;

        if (hasDebtInOtherSilo(thisSilo, _recipient)) revert DebtExistInOtherSilo();

        if (_borrowerCollateralSilo[_recipient] == address(0)) {
            _borrowerCollateralSilo[_recipient] = _borrowerCollateralSilo[_sender];
        }
    }

    /// @inheritdoc ISiloConfig
    function accrueInterestForSilo(address _silo) external virtual {
        address irm;

        if (_silo == _SILO0) {
            irm = _INTEREST_RATE_MODEL0;
        } else if (_silo == _SILO1) {
            irm = _INTEREST_RATE_MODEL1;
        } else {
            revert WrongSilo();
        }

        ISilo(_silo).accrueInterestForConfig(
            irm,
            _DAO_FEE,
            _DEPLOYER_FEE
        );
    }

    /// @inheritdoc ISiloConfig
    function accrueInterestForBothSilos() external virtual {
        ISilo(_SILO0).accrueInterestForConfig(
            _INTEREST_RATE_MODEL0,
            _DAO_FEE,
            _DEPLOYER_FEE
        );

        ISilo(_SILO1).accrueInterestForConfig(
            _INTEREST_RATE_MODEL1,
            _DAO_FEE,
            _DEPLOYER_FEE
        );
    }

    /// @inheritdoc ISiloConfig
    function getConfigs(address _borrower) external view virtual returns (
        ConfigData memory collateralConfig,
        ConfigData memory debtConfig
    ) {
        address debtSilo = getDebtSilo(_borrower);

        if (debtSilo == address(0)) return (collateralConfig, debtConfig);

        address collateralSilo = _borrowerCollateralSilo[_borrower];

        collateralConfig = getConfig(collateralSilo);
        debtConfig = getConfig(debtSilo);
    }

    /// @inheritdoc ISiloConfig
    function getConfigsForWithdraw(address _silo, address _depositOwner) external view virtual returns (
        DepositConfig memory depositConfig,
        ConfigData memory collateralConfig,
        ConfigData memory debtConfig
    ) {
        depositConfig = _getDepositConfig(_silo);
        address debtSilo = getDebtSilo(_depositOwner);

        if (debtSilo != address(0)) {
            address collateralSilo = _borrowerCollateralSilo[_depositOwner];

            collateralConfig = getConfig(collateralSilo);
            debtConfig = getConfig(debtSilo);
        }
    }

    /// @inheritdoc ISiloConfig
    function getConfigsForBorrow(address _debtSilo)
        external
        view
        virtual
        returns (ConfigData memory collateralConfig, ConfigData memory debtConfig)
    {
        address collateralSilo = _debtSilo == _SILO0 ? _SILO1 : _SILO0;

        collateralConfig = getConfig(collateralSilo);
        debtConfig = getConfig(_debtSilo);
    }

    /// @inheritdoc ISiloConfig
    function getSilos() external view virtual returns (address silo0, address silo1) {
        return (_SILO0, _SILO1);
    }

    /// @inheritdoc ISiloConfig
    function getShareTokens(address _silo)
        external
        view
        virtual
        returns (address protectedShareToken, address collateralShareToken, address debtShareToken)
    {
        if (_silo == _SILO0) {
            return (_PROTECTED_COLLATERAL_SHARE_TOKEN0, _COLLATERAL_SHARE_TOKEN0, _DEBT_SHARE_TOKEN0);
        } else if (_silo == _SILO1) {
            return (_PROTECTED_COLLATERAL_SHARE_TOKEN1, _COLLATERAL_SHARE_TOKEN1, _DEBT_SHARE_TOKEN1);
        } else {
            revert WrongSilo();
        }
    }

    /// @inheritdoc ISiloConfig
    function getAssetForSilo(address _silo) external view virtual returns (address asset) {
        if (_silo == _SILO0) {
            return _TOKEN0;
        } else if (_silo == _SILO1) {
            return _TOKEN1;
        } else {
            revert WrongSilo();
        }
    }

    /// @inheritdoc ISiloConfig
    function getFeesWithAsset(address _silo)
        external
        view
        virtual
        returns (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset)
    {
        daoFee = _DAO_FEE;
        deployerFee = _DEPLOYER_FEE;

        if (_silo == _SILO0) {
            asset = _TOKEN0;
            flashloanFee = _FLASHLOAN_FEE0;
        } else if (_silo == _SILO1) {
            asset = _TOKEN1;
            flashloanFee = _FLASHLOAN_FEE1;
        } else {
            revert WrongSilo();
        }
    }

    /// @inheritdoc ISiloConfig
    function getCollateralShareTokenAndAsset(address _silo, ISilo.CollateralType _collateralType)
        external
        view
        virtual
        returns (address shareToken, address asset)
    {
        if (_silo == _SILO0) {
            return _collateralType == ISilo.CollateralType.Collateral
                ? (_COLLATERAL_SHARE_TOKEN0, _TOKEN0)
                : (_PROTECTED_COLLATERAL_SHARE_TOKEN0, _TOKEN0);
        } else if (_silo == _SILO1) {
            return _collateralType == ISilo.CollateralType.Collateral
                ? (_COLLATERAL_SHARE_TOKEN1, _TOKEN1)
                : (_PROTECTED_COLLATERAL_SHARE_TOKEN1, _TOKEN1);
        } else {
            revert WrongSilo();
        }
    }

    /// @inheritdoc ISiloConfig
    function getDebtShareTokenAndAsset(address _silo)
        external
        view
        virtual
        returns (address shareToken, address asset)
    {
        if (_silo == _SILO0) {
            return (_DEBT_SHARE_TOKEN0, _TOKEN0);
        } else if (_silo == _SILO1) {
            return (_DEBT_SHARE_TOKEN1, _TOKEN1);
        } else {
            revert WrongSilo();
        }
    }

    /// @inheritdoc ISiloConfig
    function getConfig(address _silo) public view virtual returns (ConfigData memory config) {
        if (_silo == _SILO0) {
            config = _silo0ConfigData();
        } else if (_silo == _SILO1) {
            config = _silo1ConfigData();
        } else {
            revert WrongSilo();
        }
    }

    /// @inheritdoc ISiloConfig
    function hasDebtInOtherSilo(address _thisSilo, address _borrower) public view returns (bool hasDebt) {
        if (_thisSilo == _SILO0) {
            hasDebt = _balanceOf(_DEBT_SHARE_TOKEN1, _borrower) != 0;
        } else if (_thisSilo == _SILO1) {
            hasDebt = _balanceOf(_DEBT_SHARE_TOKEN0, _borrower) != 0;
        } else {
            revert WrongSilo();
        }
     }

    /// @inheritdoc ISiloConfig
    function getDebtSilo(address _borrower) public view virtual returns (address debtSilo) {
        uint256 debtBal0 = _balanceOf(_DEBT_SHARE_TOKEN0, _borrower);
        uint256 debtBal1 = _balanceOf(_DEBT_SHARE_TOKEN1, _borrower);

        if (debtBal0 > 0 && debtBal1 > 0) revert DebtExistInOtherSilo();
        if (debtBal0 == 0 && debtBal1 == 0) return address(0);

        debtSilo = debtBal0 != 0 ? _SILO0 : _SILO1;
    }

    function _silo0ConfigData() internal view returns (ConfigData memory config) {
        config = ConfigData({
            daoFee: _DAO_FEE,
            deployerFee: _DEPLOYER_FEE,
            silo: _SILO0,
            otherSilo: _SILO1,
            token: _TOKEN0,
            protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN0,
            collateralShareToken: _COLLATERAL_SHARE_TOKEN0,
            debtShareToken: _DEBT_SHARE_TOKEN0,
            solvencyOracle: _SOLVENCY_ORACLE0,
            maxLtvOracle: _MAX_LTV_ORACLE0,
            interestRateModel: _INTEREST_RATE_MODEL0,
            maxLtv: _MAX_LTV0,
            lt: _LT0,
            liquidationFee: _LIQUIDATION_FEE0,
            flashloanFee: _FLASHLOAN_FEE0,
            hookReceiver: _HOOK_RECEIVER,
            callBeforeQuote: _CALL_BEFORE_QUOTE0
        });
    }

    function _silo1ConfigData() internal view returns (ConfigData memory config) {
        config = ConfigData({
            daoFee: _DAO_FEE,
            deployerFee: _DEPLOYER_FEE,
            silo: _SILO1,
            otherSilo: _SILO0,
            token: _TOKEN1,
            protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN1,
            collateralShareToken: _COLLATERAL_SHARE_TOKEN1,
            debtShareToken: _DEBT_SHARE_TOKEN1,
            solvencyOracle: _SOLVENCY_ORACLE1,
            maxLtvOracle: _MAX_LTV_ORACLE1,
            interestRateModel: _INTEREST_RATE_MODEL1,
            maxLtv: _MAX_LTV1,
            lt: _LT1,
            liquidationFee: _LIQUIDATION_FEE1,
            flashloanFee: _FLASHLOAN_FEE1,
            hookReceiver: _HOOK_RECEIVER,
            callBeforeQuote: _CALL_BEFORE_QUOTE1
        });
    }

    function _getDepositConfig(address _silo) internal view virtual returns (DepositConfig memory config) {
        if (_silo == _SILO0) {
            config = DepositConfig({
                silo: _SILO0,
                token: _TOKEN0,
                collateralShareToken: _COLLATERAL_SHARE_TOKEN0,
                protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN0,
                daoFee: _DAO_FEE,
                deployerFee: _DEPLOYER_FEE,
                interestRateModel: _INTEREST_RATE_MODEL0
            });
        } else if (_silo == _SILO1) {
            config = DepositConfig({
                silo: _SILO1,
                token: _TOKEN1,
                collateralShareToken: _COLLATERAL_SHARE_TOKEN1,
                protectedShareToken: _PROTECTED_COLLATERAL_SHARE_TOKEN1,
                daoFee: _DAO_FEE,
                deployerFee: _DEPLOYER_FEE,
                interestRateModel: _INTEREST_RATE_MODEL1
            });
        } else {
            revert WrongSilo();
        }
    }

    function _onlySiloOrTokenOrHookReceiver() internal view override {
        if (msg.sender != _SILO0 &&
            msg.sender != _SILO1 &&
            msg.sender != _HOOK_RECEIVER &&
            msg.sender != _COLLATERAL_SHARE_TOKEN0 &&
            msg.sender != _COLLATERAL_SHARE_TOKEN1 &&
            msg.sender != _PROTECTED_COLLATERAL_SHARE_TOKEN0 &&
            msg.sender != _PROTECTED_COLLATERAL_SHARE_TOKEN1 &&
            msg.sender != _DEBT_SHARE_TOKEN0 &&
            msg.sender != _DEBT_SHARE_TOKEN1
        ) {
            revert OnlySiloOrHookReceiver();
        }
    }

    function _onlySilo() internal view virtual {
        if (msg.sender != _SILO0 && msg.sender != _SILO1) revert OnlySilo();
    }

    function _balanceOf(address _token, address _user) internal view returns (uint256 balance) {
        balance = IERC20(_token).balanceOf(_user);
    }
}
