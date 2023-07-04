// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {ISiloConfig} from "../interface/ISiloConfig.sol";
import {ISiloOracle} from "../interface/ISiloOracle.sol";
import {ISilo, ISiloFactory} from "../interface/ISilo.sol";
import {IInterestRateModel} from "../interface/IInterestRateModel.sol";
import {IShareToken} from "../interface/IShareToken.sol";

// solhint-disable ordering

library SiloStdLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    enum TokenType {
        Protected,
        Collateral,
        Debt
    }

    uint256 internal constant _PRECISION_DECIMALS = 1e18;
    uint256 internal constant _INFINITY = type(uint256).max;

    error ZeroAssets();
    error ZeroShares();
    error WrongToken();
    error DepositNotPossible();
    error NothingToWithdraw();
    error NotSolvent();
    error NotEnoughLiquidity();

    /// @notice Emitted when deposit is made
    /// @param token asset address that was deposited
    /// @param depositor wallet address that deposited asset
    /// @param receiver wallet address that received shares in Silo
    /// @param assets amount of asset that was deposited
    /// @param shares amount of shares that was minted
    /// @param isProtected type of deposit, if true, deposited as protected (cannot be borrowed by other users)
    event Deposit(
        address indexed token,
        address indexed depositor,
        address indexed receiver,
        uint256 assets,
        uint256 shares,
        bool isProtected
    );

    /// @notice Emitted when withdraw is made
    /// @param token asset address that was withdrew
    /// @param owner wallet address that deposited asset
    /// @param receiver wallet address that received asset
    /// @param assets amount of asset that was withdrew
    /// @param shares amount of shares that was burn
    /// @param isProtected type of withdraw, if true, withdraw protected deposit
    event Withdraw(
        address indexed token,
        address indexed owner,
        address indexed receiver,
        uint256 assets,
        uint256 shares,
        bool isProtected
    );

    /// @notice Emitted when user borrows
    /// @param token asset address that was borrowed
    /// @param borrower wallet address that borrowed asset
    /// @param receiver wallet address that received asset
    /// @param assets amount of asset that was borrowed
    /// @param shares amount of shares that was minted
    event Borrow(address token, address borrower, address receiver, uint256 assets, uint256 shares);

    // TODO: check rounding up/down
    function toAssets(uint256 _shares, uint256 _totalAmount, uint256 _totalShares) internal pure returns (uint256) {
        if (_totalShares == 0 || _totalAmount == 0) {
            return 0;
        }

        uint256 result = _shares * _totalAmount / _totalShares;

        // Prevent rounding error
        if (result == 0 && _shares != 0) {
            revert ZeroAssets();
        }

        return result;
    }

    // TODO: check rounding up/down
    function toShare(uint256 _amount, uint256 _totalAmount, uint256 _totalShares) internal pure returns (uint256) {
        if (_totalShares == 0 || _totalAmount == 0) {
            return _amount;
        }

        uint256 result = _amount * _totalShares / _totalAmount;

        // Prevent rounding error
        if (result == 0 && _amount != 0) {
            revert ZeroShares();
        }

        return result;
    }

    function amountWithInterest(address _asset, uint256 _amount, address _model)
        internal
        view
        returns (uint256 amount)
    {
        uint256 rcomp = IInterestRateModel(_model).getCompoundInterestRate(address(this), _asset, block.timestamp);

        // deployer and dao fee can be ignored because interest is fully added to AssetStorage anyway
        amount = _amount + _amount * rcomp / _PRECISION_DECIMALS;
    }

    // solhint-disable-next-line code-complexity
    function findShareToken(ISiloConfig.ConfigData memory _configData, TokenType _tokenType, address _token)
        internal
        pure
        returns (IShareToken shareToken)
    {
        if (_configData.token0 == _token) {
            if (_tokenType == TokenType.Protected) return IShareToken(_configData.protectedCollateralShareToken0);
            else if (_tokenType == TokenType.Collateral) return IShareToken(_configData.collateralShareToken0);
            else if (_tokenType == TokenType.Debt) return IShareToken(_configData.debtShareToken0);
        } else if (_configData.token1 == _token) {
            if (_tokenType == TokenType.Protected) return IShareToken(_configData.protectedCollateralShareToken1);
            else if (_tokenType == TokenType.Collateral) return IShareToken(_configData.collateralShareToken1);
            else if (_tokenType == TokenType.Debt) return IShareToken(_configData.debtShareToken1);
        } else {
            revert WrongToken();
        }
    }

    function findModel(ISiloConfig.ConfigData memory _configData, address _token) internal pure returns (address) {
        if (_configData.token0 == _token) {
            return _configData.interestRateModel0;
        } else if (_configData.token1 == _token) {
            return _configData.interestRateModel1;
        } else {
            revert WrongToken();
        }
    }

    function liquidity(address _token, mapping(address => ISilo.AssetStorage) storage _assetStorage)
        internal
        view
        returns (uint256 liquidAssets)
    {
        liquidAssets = _assetStorage[_token].collateralAssets - _assetStorage[_token].debtAssets;
    }

    struct LtvData {
        address debtToken;
        address collateralToken;
        IShareToken protectedCollateralShareToken;
        IShareToken collateralShareToken;
        ISiloOracle debtOracle;
        ISiloOracle collateralOracle;
        address collateralInterestRateModel;
        uint256 debtAssets;
        uint256 collateralAssets;
        uint256 debtValue;
        uint256 collateralValue;
        bool isToken0Collateral;
    }

    // solhint-disable-next-line function-max-lines
    function _getLtvInternal(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        bool _useLtOracle,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private view returns (LtvData memory ltvData) {
        uint256 debtShareToken0Balance = IShareToken(_configData.debtShareToken0).balanceOf(_borrower);

        if (debtShareToken0Balance != 0) {
            // borrowed token0, collateralized token1
            ltvData.debtAssets = toAssets(
                debtShareToken0Balance,
                amountWithInterest(
                    _configData.token0, _assetStorage[_configData.token0].debtAssets, _configData.interestRateModel0
                ),
                IShareToken(_configData.debtShareToken0).totalSupply()
            );

            ltvData.debtToken = _configData.token0;
            ltvData.collateralToken = _configData.token1;

            ltvData.collateralInterestRateModel = _configData.interestRateModel1;

            // If LTV is needed for solvency, ltOracle should be used. If ltOracle is not set, fallback to ltvOracle.
            ltvData.debtOracle = _useLtOracle && _configData.ltOracle0 != address(0)
                ? ISiloOracle(_configData.ltOracle0)
                : ISiloOracle(_configData.ltvOracle0);
            ltvData.collateralOracle = _useLtOracle && _configData.ltOracle1 != address(0)
                ? ISiloOracle(_configData.ltOracle1)
                : ISiloOracle(_configData.ltvOracle1);

            ltvData.protectedCollateralShareToken = IShareToken(_configData.protectedCollateralShareToken1);
            ltvData.collateralShareToken = IShareToken(_configData.collateralShareToken1);
        } else {
            uint256 debtShareToken1Balance = IShareToken(_configData.debtShareToken1).balanceOf(_borrower);

            if (debtShareToken1Balance != 0) {
                // borrowed token1, collateralized token0
                ltvData.debtAssets = toAssets(
                    debtShareToken1Balance,
                    amountWithInterest(
                        _configData.token1, _assetStorage[_configData.token1].debtAssets, _configData.interestRateModel1
                    ),
                    IShareToken(_configData.debtShareToken1).totalSupply()
                );

                ltvData.debtToken = _configData.token1;
                ltvData.collateralToken = _configData.token0;

                ltvData.collateralInterestRateModel = _configData.interestRateModel0;

                // If LTV is needed for solvency, ltOracle should be used. If ltOracle is not set,
                // fallback to ltvOracle.
                ltvData.debtOracle = _useLtOracle && _configData.ltOracle1 != address(0)
                    ? ISiloOracle(_configData.ltOracle1)
                    : ISiloOracle(_configData.ltvOracle1);
                ltvData.collateralOracle = _useLtOracle && _configData.ltOracle0 != address(0)
                    ? ISiloOracle(_configData.ltOracle0)
                    : ISiloOracle(_configData.ltvOracle0);

                ltvData.protectedCollateralShareToken = IShareToken(_configData.protectedCollateralShareToken0);
                ltvData.collateralShareToken = IShareToken(_configData.collateralShareToken0);

                ltvData.isToken0Collateral = true;
            } else {
                // nothing borrowed
                return ltvData;
            }
        }

        uint256 protectedBalance = ltvData.protectedCollateralShareToken.balanceOf(_borrower);
        uint256 protectedAssets;

        if (protectedBalance != 0) {
            protectedAssets = toAssets(
                protectedBalance,
                _assetStorage[ltvData.collateralToken].protectedAssets,
                IShareToken(ltvData.protectedCollateralShareToken).totalSupply()
            );
        }

        uint256 collateralBalance = ltvData.collateralShareToken.balanceOf(_borrower);
        uint256 collateralAssets;

        if (collateralBalance != 0) {
            collateralAssets = toAssets(
                collateralBalance,
                amountWithInterest(
                    ltvData.collateralToken,
                    _assetStorage[ltvData.collateralToken].collateralAssets,
                    ltvData.collateralInterestRateModel
                ),
                IShareToken(ltvData.collateralShareToken).totalSupply()
            );
        }

        /// @dev sum of assets cannot be bigger than total supply which must fit in uint256
        unchecked {
            ltvData.collateralAssets = protectedAssets + collateralAssets;
        }
    }

    function getLtvView(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        bool _useLtOracle,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256, bool, uint256, uint256, uint256) {
        LtvData memory ltvData = _getLtvInternal(_configData, _borrower, _useLtOracle, _assetStorage);

        if (ltvData.debtAssets == 0) return (0, false, 0, 0, 0);

        // if no oracle is set, assume price 1
        ltvData.debtValue = address(ltvData.debtOracle) != address(0)
            ? ltvData.debtOracle.quoteView(ltvData.debtAssets, ltvData.debtToken)
            : ltvData.debtAssets;

        // if no oracle is set, assume price 1
        ltvData.collateralValue = address(ltvData.collateralOracle) != address(0)
            ? ltvData.collateralOracle.quoteView(ltvData.collateralAssets, ltvData.collateralToken)
            : ltvData.collateralAssets;

        return (
            ltvData.debtValue * _PRECISION_DECIMALS / ltvData.collateralValue,
            ltvData.isToken0Collateral,
            ltvData.debtValue,
            ltvData.collateralValue,
            ltvData.collateralAssets
        );
    }

    /// @return LTV
    /// @return isToken0Collateral
    /// @return debtValue
    /// @return collateralValue
    /// @return collateralAssets
    function getLtv(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        bool _useLtOracle,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256, bool, uint256, uint256, uint256) {
        LtvData memory ltvData = _getLtvInternal(_configData, _borrower, _useLtOracle, _assetStorage);

        if (ltvData.debtAssets == 0) return (0, false, 0, 0, 0);

        // if no oracle is set, assume price 1
        ltvData.debtValue = address(ltvData.debtOracle) != address(0)
            ? ltvData.debtOracle.quote(ltvData.debtAssets, ltvData.debtToken)
            : ltvData.debtAssets;

        // if no oracle is set, assume price 1
        ltvData.collateralValue = address(ltvData.collateralOracle) != address(0)
            ? ltvData.collateralOracle.quote(ltvData.collateralAssets, ltvData.collateralToken)
            : ltvData.collateralAssets;

        return (
            ltvData.debtValue * _PRECISION_DECIMALS / ltvData.collateralValue,
            ltvData.isToken0Collateral,
            ltvData.debtValue,
            ltvData.collateralValue,
            ltvData.collateralAssets
        );
    }

    function _isSolventInternal(
        ISiloConfig.ConfigData memory _configData,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private returns (bool) {
        (uint256 ltv, bool isToken0Collateral,,,) = getLtv(_configData, _borrower, true, _assetStorage);

        if (isToken0Collateral) {
            return ltv <= _configData.lt0;
        } else {
            return ltv <= _configData.lt1;
        }
    }

    function isSolvent(
        ISiloConfig _config,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (bool) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return _isSolventInternal(configData, _borrower, _assetStorage);
    }

    function _depositPossibleInternal(ISiloConfig.ConfigData memory _configData, address _token, address _depositor)
        private
        view
        returns (bool)
    {
        IShareToken shareToken = findShareToken(_configData, TokenType.Debt, _token);
        return shareToken.balanceOf(_depositor) == 0;
    }

    function depositPossible(ISiloConfig _config, address _token, address _depositor) internal view returns (bool) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return _depositPossibleInternal(configData, _token, _depositor);
    }

    function _borrowPossibleInternal(ISiloConfig.ConfigData memory _configData, address _token, address _borrower)
        private
        view
        returns (bool)
    {
        IShareToken protectedShareToken = findShareToken(_configData, TokenType.Protected, _token);
        IShareToken collateralShareToken = findShareToken(_configData, TokenType.Collateral, _token);

        return protectedShareToken.balanceOf(_borrower) == 0 && collateralShareToken.balanceOf(_borrower) == 0;
    }

    function borrowPossible(ISiloConfig _config, address _token, address _borrower) internal view returns (bool) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return _borrowPossibleInternal(configData, _token, _borrower);
    }

    function getMaxLtv(ISiloConfig _config, address _token) internal view returns (uint256) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        if (configData.token0 == _token) {
            return configData.maxLtv0;
        } else if (configData.token1 == _token) {
            return configData.maxLtv1;
        } else {
            revert WrongToken();
        }
    }

    function getLt(ISiloConfig _config, address _token) internal view returns (uint256) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        if (configData.token0 == _token) {
            return configData.lt0;
        } else if (configData.token1 == _token) {
            return configData.lt1;
        } else {
            revert WrongToken();
        }
    }

    function tokens(ISiloConfig _config) internal view returns (address[2] memory assetTokenAddresses) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        assetTokenAddresses[0] = configData.token0;
        assetTokenAddresses[1] = configData.token1;
    }

    function totalAssets(
        ISiloConfig _config,
        address _token,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        if (configData.token0 == _token || configData.token1 == _token) {
            /// @dev sum of assets cannot be bigger than total supply which must fit in uint256
            unchecked {
                return _assetStorage[_token].protectedAssets + _assetStorage[_token].collateralAssets;
            }
        } else {
            revert WrongToken();
        }
    }

    function getTotalAmountAndTotalShares(
        ISiloConfig.ConfigData memory _configData,
        address _token,
        bool _isProtected,
        bool _isDebt,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 totalAmount, uint256 totalShares) {
        IShareToken shareToken;

        if (_isDebt) {
            shareToken = findShareToken(_configData, TokenType.Debt, _token);
            totalAmount = amountWithInterest(_token, _assetStorage[_token].debtAssets, findModel(_configData, _token));
        } else if (_isProtected) {
            shareToken = findShareToken(_configData, TokenType.Protected, _token);
            totalAmount = _assetStorage[_token].protectedAssets;
        } else {
            shareToken = findShareToken(_configData, TokenType.Collateral, _token);
            totalAmount =
                amountWithInterest(_token, _assetStorage[_token].collateralAssets, findModel(_configData, _token));
        }

        totalShares = shareToken.totalSupply();
    }

    function _convertToSharesInternal(
        ISiloConfig.ConfigData memory _configData,
        address _token,
        uint256 _assets,
        bool _isProtected,
        bool _isDebt,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private view returns (uint256) {
        if (_assets == 0) return 0;

        (uint256 totalAmount, uint256 totalShares) =
            getTotalAmountAndTotalShares(_configData, _token, _isProtected, _isDebt, _assetStorage);

        return toShare(_assets, totalAmount, totalShares);
    }

    function convertToShares(
        ISiloConfig _config,
        address _token,
        uint256 _assets,
        bool _isProtected,
        bool _isDebt,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return _convertToSharesInternal(configData, _token, _assets, _isProtected, _isDebt, _assetStorage);
    }

    function _convertToAssetsInternal(
        ISiloConfig.ConfigData memory _configData,
        address _token,
        uint256 _shares,
        bool _isProtected,
        bool _isDebt,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private view returns (uint256) {
        if (_shares == 0) return 0;

        (uint256 totalAmount, uint256 totalShares) =
            getTotalAmountAndTotalShares(_configData, _token, _isProtected, _isDebt, _assetStorage);

        return toAssets(_shares, totalAmount, totalShares);
    }

    function convertToAssets(
        ISiloConfig _config,
        address _token,
        uint256 _shares,
        bool _isProtected,
        bool _isDebt,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return _convertToAssetsInternal(configData, _token, _shares, _isProtected, _isDebt, _assetStorage);
    }

    function maxDeposit(
        ISiloConfig _config,
        address _receiver,
        address _token,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxAssets) {
        if (!depositPossible(_config, _token, _receiver)) return 0;

        if (_isProtected) {
            /// @dev protectedAssets cannot be bigger then uin256 itself
            unchecked {
                return type(uint256).max - _assetStorage[_token].protectedAssets;
            }
        } else {
            /// @dev collateralAssets cannot be bigger then uin256 itself
            unchecked {
                return type(uint256).max - _assetStorage[_token].collateralAssets;
            }
        }
    }

    function previewDeposit(
        ISiloConfig _config,
        address _receiver,
        address _token,
        uint256 _assets,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        if (!_depositPossibleInternal(configData, _token, _receiver)) revert DepositNotPossible();

        return _convertToSharesInternal(configData, _token, _assets, _isProtected, false, _assetStorage);
    }

    function _depositInternal(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        address _receiver,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private returns (uint256 collateralAssets, IShareToken collateralShareToken) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        _accrueInterestInternal(configData, _factory, _token, _assetStorage);

        if (!depositPossible(_config, _token, _receiver)) revert DepositNotPossible();

        if (_isProtected) {
            collateralAssets = _assetStorage[_token].protectedAssets;
            collateralShareToken = findShareToken(configData, TokenType.Protected, _token);
        } else {
            collateralAssets = _assetStorage[_token].collateralAssets;
            collateralShareToken = findShareToken(configData, TokenType.Collateral, _token);
        }
    }

    function deposit(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        address _depositor,
        address _receiver,
        uint256 _assets,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 shares) {
        (uint256 collateralAssets, IShareToken collateralShareToken) =
            _depositInternal(_config, _factory, _token, _receiver, _isProtected, _assetStorage);

        shares = toShare(_assets, collateralAssets, collateralShareToken.totalSupply());
        collateralShareToken.mint(_receiver, msg.sender, shares);

        IERC20Upgradeable(_token).safeTransferFrom(_depositor, address(this), _assets);

        emit Deposit(_token, _depositor, _receiver, _assets, shares, _isProtected);
    }

    function maxMint(ISiloConfig _config, address _receiver, address _token, bool _isProtected)
        internal
        view
        returns (uint256 maxShares)
    {
        if (!depositPossible(_config, _token, _receiver)) return 0;

        ISiloConfig.ConfigData memory configData = _config.getConfig();

        IShareToken shareToken;

        if (_isProtected) {
            shareToken = findShareToken(configData, TokenType.Protected, _token);
        } else {
            shareToken = findShareToken(configData, TokenType.Collateral, _token);
        }

        return type(uint256).max - shareToken.totalSupply();
    }

    function previewMint(
        ISiloConfig _config,
        address _receiver,
        address _token,
        uint256 _shares,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        if (!depositPossible(_config, _token, _receiver)) revert DepositNotPossible();

        return convertToAssets(_config, _token, _shares, _isProtected, false, _assetStorage);
    }

    function mint(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        address _depositor,
        address _receiver,
        uint256 _shares,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        (uint256 collateralAssets, IShareToken collateralToken) =
            _depositInternal(_config, _factory, _token, _receiver, _isProtected, _assetStorage);

        assets = toAssets(_shares, collateralAssets, collateralToken.totalSupply());
        collateralToken.mint(_receiver, msg.sender, _shares);

        IERC20Upgradeable(_token).safeTransferFrom(_depositor, address(this), assets);

        emit Deposit(_token, _depositor, _receiver, assets, _shares, _isProtected);
    }

    function _maxWithdrawInternal(
        ISiloConfig.ConfigData memory _configData,
        address _token,
        address _owner,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private view returns (uint256 shares, uint256 assets) {
        IShareToken shareToken;
        bool isToken0Collateral;
        uint256 totalAmount;
        uint256 debtValue;
        uint256 collateralValue;
        uint256 liquidAssets = liquidity(_token, _assetStorage);

        if (_isProtected) {
            shareToken = findShareToken(_configData, TokenType.Protected, _token);
            totalAmount = _assetStorage[_token].protectedAssets;
        } else {
            shareToken = findShareToken(_configData, TokenType.Collateral, _token);
            totalAmount = _assetStorage[_token].collateralAssets;
        }

        shares = shareToken.balanceOf(_owner);

        // no deposits of _token
        if (shares == 0) return (0, 0);

        (, isToken0Collateral, debtValue, collateralValue, assets) =
            getLtvView(_configData, _owner, true, _assetStorage);

        // must deduct debt
        if (debtValue > 0) {
            uint256 lt = isToken0Collateral ? _configData.lt0 : _configData.lt1;
            uint256 spareCollateralValue = collateralValue - (debtValue * _PRECISION_DECIMALS / lt);
            assets = spareCollateralValue * _PRECISION_DECIMALS / collateralValue * assets / _PRECISION_DECIMALS;
            shares = toShare(assets, totalAmount, shareToken.totalSupply());
        }

        // cannot withdraw more then liquidity
        if (assets > liquidAssets) {
            assets = liquidAssets;
            shares = toShare(assets, totalAmount, shareToken.totalSupply());
        }
    }

    function maxWithdraw(
        ISiloConfig _config,
        address _token,
        address _owner,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxAssets) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();
        (, maxAssets) = _maxWithdrawInternal(configData, _token, _owner, _isProtected, _assetStorage);
    }

    function previewWithdraw(
        ISiloConfig _config,
        address _token,
        uint256 _assets,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        return convertToShares(_config, _token, _assets, _isProtected, false, _assetStorage);
    }

    // solhint-disable-next-line function-max-lines
    function _withdrawInternal(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        bool _isProtected,
        bool _isWithdraw,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private returns (uint256 assets, uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        _accrueInterestInternal(configData, _factory, _token, _assetStorage);

        IShareToken shareToken;
        uint256 totalAmount;

        if (_isProtected) {
            shareToken = findShareToken(configData, TokenType.Protected, _token);
            totalAmount = _assetStorage[_token].protectedAssets;
        } else {
            shareToken = findShareToken(configData, TokenType.Collateral, _token);
            totalAmount = _assetStorage[_token].collateralAssets;
        }

        uint256 totalShares = shareToken.totalSupply();
        uint256 shareBalance = shareToken.balanceOf(_owner);

        if (_isWithdraw) {
            // it's withdraw so assets are user input
            shares = toShare(_assets, totalAmount, totalShares);
            assets = _assets;
        } else {
            // it's redeem so shares are user input
            shares = _shares;
            assets = toAssets(_shares, totalAmount, totalShares);
        }

        if (assets == 0 || shareBalance == 0 || shares == 0) revert NothingToWithdraw();

        // withdraw max
        if (shareBalance < shares) {
            shares = shareBalance;
            assets = toAssets(shares, totalAmount, totalShares);
        }

        if (assets > liquidity(_token, _assetStorage)) revert NotEnoughLiquidity();

        if (_isProtected) {
            // TODO: write FV (formal verification) rule and comment
            unchecked {
                _assetStorage[_token].protectedAssets = totalAmount - assets;
            }
        } else {
            // TODO: write FV (formal verification) rule and comment
            unchecked {
                _assetStorage[_token].collateralAssets = totalAmount - assets;
            }
        }

        /// @dev `burn` checks if `_spender` is allowed to withdraw `_owner` assets
        shareToken.burn(_owner, _spender, shares);
        /// @dev fee-on-transfer is ignored
        IERC20Upgradeable(_token).safeTransferFrom(address(this), _receiver, assets);

        /// @dev `_owner` must be solvent
        if (!_isSolventInternal(configData, _owner, _assetStorage)) revert NotSolvent();

        emit Withdraw(_token, _owner, _receiver, assets, shares, _isProtected);
    }

    function withdraw(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _assets,
        address _receiver,
        address _owner,
        address _spender,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 shares) {
        (, shares) = _withdrawInternal(
            _config, _factory, _token, _assets, 0, _receiver, _owner, _spender, _isProtected, true, _assetStorage
        );
    }

    function maxRedeem(
        ISiloConfig _config,
        address _token,
        address _owner,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxShares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();
        (maxShares,) = _maxWithdrawInternal(configData, _token, _owner, _isProtected, _assetStorage);
    }

    function previewRedeem(
        ISiloConfig _config,
        address _token,
        uint256 _shares,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) external view returns (uint256 assets) {
        return convertToAssets(_config, _token, _shares, _isProtected, false, _assetStorage);
    }

    function redeem(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _receiver,
        address _owner,
        address _spender,
        bool _isProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        (assets,) = _withdrawInternal(
            _config, _factory, _token, 0, _shares, _receiver, _owner, _spender, _isProtected, false, _assetStorage
        );
    }

    // solhint-disable-next-line function-max-lines
    function _transitionInternal(
        ISiloConfig.ConfigData memory _configData,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _owner,
        address _spender,
        bool _toProtected,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private returns (uint256 assets) {
        _accrueInterestInternal(_configData, _factory, _token, _assetStorage);

        IShareToken fromShareToken;
        uint256 fromTotalAmount;
        IShareToken toShareToken;
        uint256 toTotalAmount;

        if (_toProtected) {
            fromShareToken = findShareToken(_configData, TokenType.Collateral, _token);
            fromTotalAmount = _assetStorage[_token].collateralAssets;
            toShareToken = findShareToken(_configData, TokenType.Protected, _token);
            toTotalAmount = _assetStorage[_token].protectedAssets;
        } else {
            fromShareToken = findShareToken(_configData, TokenType.Protected, _token);
            fromTotalAmount = _assetStorage[_token].protectedAssets;
            toShareToken = findShareToken(_configData, TokenType.Collateral, _token);
            toTotalAmount = _assetStorage[_token].collateralAssets;
        }

        uint256 fromTotalShares = fromShareToken.totalSupply();
        uint256 shareBalance = fromShareToken.balanceOf(_owner);
        assets = toAssets(_shares, fromTotalAmount, fromTotalShares);

        if (assets == 0 || shareBalance == 0 || _shares == 0) revert NothingToWithdraw();

        // withdraw max
        if (shareBalance < _shares) {
            _shares = shareBalance;
            assets = toAssets(_shares, fromTotalAmount, fromTotalShares);
        }

        uint256 toShares = toShare(assets, toTotalAmount, toShareToken.totalSupply());

        if (_toProtected) {
            _assetStorage[_token].protectedAssets = toTotalAmount + assets;
            _assetStorage[_token].collateralAssets = fromTotalAmount - assets;
        } else {
            _assetStorage[_token].protectedAssets = fromTotalAmount - assets;
            _assetStorage[_token].collateralAssets = toTotalAmount + assets;
        }

        /// @dev burn checks if _spender is allowed to transition _owner tokens
        fromShareToken.burn(_owner, _spender, _shares);
        toShareToken.mint(_owner, _spender, toShares);

        /// @dev `_owner` must be solvent
        if (!_isSolventInternal(_configData, _owner, _assetStorage)) revert NotSolvent();

        emit Withdraw(_token, _owner, _owner, assets, _shares, !_toProtected);
        emit Deposit(_token, _owner, _owner, assets, toShares, _toProtected);
    }

    function transitionToProtected(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _owner,
        address _spender,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return _transitionInternal(configData, _factory, _token, _shares, _owner, _spender, true, _assetStorage);
    }

    function transitionFromProtected(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _owner,
        address _spender,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        return _transitionInternal(configData, _factory, _token, _shares, _owner, _spender, false, _assetStorage);
    }

    // solhint-disable-next-line function-max-lines
    function _maxBorrowInternal(
        ISiloConfig _config,
        address _token,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private view returns (uint256 maxAssets, uint256 maxShares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        IShareToken protectedShareToken = findShareToken(configData, TokenType.Protected, _token);
        IShareToken collateralShareToken = findShareToken(configData, TokenType.Collateral, _token);
        IShareToken debtShareToken = findShareToken(configData, TokenType.Debt, _token);

        uint256 protectedShareBalance = protectedShareToken.balanceOf(_borrower);
        uint256 collateralShareBalance = collateralShareToken.balanceOf(_borrower);
        uint256 debtShareBalance = debtShareToken.balanceOf(_borrower);

        // no collateral, no borrow
        if (protectedShareBalance + collateralShareBalance == 0) return (0, 0);

        uint256 totalCollateralAssets;
        uint256 debtAssets;

        if (protectedShareBalance != 0) {
            totalCollateralAssets +=
                _convertToAssetsInternal(configData, _token, protectedShareBalance, true, false, _assetStorage);
        }

        if (collateralShareBalance != 0) {
            totalCollateralAssets +=
                _convertToAssetsInternal(configData, _token, collateralShareBalance, false, false, _assetStorage);
        }

        if (debtShareBalance != 0) {
            debtAssets = _convertToAssetsInternal(configData, _token, debtShareBalance, false, true, _assetStorage);
        }

        ISiloOracle collateralOracle;
        address collateralToken;
        uint256 maxLtv;

        ISiloOracle debtOracle;
        address debtToken;

        if (_token == configData.token0) {
            collateralToken = configData.token1;
            collateralOracle = ISiloOracle(configData.ltvOracle1);
            maxLtv = configData.maxLtv1;

            debtToken = configData.token0;
            debtOracle = ISiloOracle(configData.ltvOracle0);
        } else {
            collateralToken = configData.token0;
            collateralOracle = ISiloOracle(configData.ltvOracle0);
            maxLtv = configData.maxLtv0;

            debtToken = configData.token1;
            debtOracle = ISiloOracle(configData.ltvOracle1);
        }

        // if no oracle is set, assume price 1
        uint256 collateralValue = address(collateralOracle) != address(0)
            ? collateralOracle.quoteView(totalCollateralAssets, collateralToken)
            : totalCollateralAssets;

        uint256 maxDebtValue = collateralValue * maxLtv / _PRECISION_DECIMALS;

        uint256 debtValue = address(debtOracle) != address(0) ? debtOracle.quoteView(debtAssets, debtToken) : debtAssets;

        // if LTV is higher than LT user cannot borrow more
        if (debtValue >= maxDebtValue) return (0, 0);

        maxAssets = debtAssets * maxDebtValue / debtValue - debtAssets;
        maxShares = toShare(maxAssets, debtAssets, debtShareToken.totalSupply());
    }

    function maxBorrow(
        ISiloConfig _config,
        address _token,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxAssets) {
        (maxAssets,) = _maxBorrowInternal(_config, _token, _borrower, _assetStorage);
    }

    function previewBorrow(
        ISiloConfig _config,
        address _token,
        uint256 _assets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 shares) {
        return convertToShares(_config, _token, _assets, false, true, _assetStorage);
    }

    function _borrowInternal(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        bool _isAssets,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private returns (uint256 assets, uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        _accrueInterestInternal(configData, _factory, _token, _assetStorage);

        IShareToken debtShareToken = findShareToken(configData, TokenType.Debt, _token);
        uint256 totalDebtAmount = _assetStorage[_token].debtAssets;
        uint256 totalDebtShares = debtShareToken.totalSupply();

        if (_isAssets) {
            // borrowing assets
            shares = toShare(_assets, totalDebtAmount, totalDebtShares);
            assets = _assets;
        } else {
            // borrowing shares
            shares = _shares;
            assets = toAssets(_shares, totalDebtAmount, totalDebtShares);
        }

        if (assets > liquidity(_token, _assetStorage)) revert NotEnoughLiquidity();

        /// @dev add new debt
        _assetStorage[_token].debtAssets += assets;
        /// @dev mint checks if _spender is allowed to borrow on the account of _borrower
        debtShareToken.mint(_borrower, _spender, shares);
        /// @dev/ @dev fee-on-transfer is ignored
        IERC20Upgradeable(_token).safeTransferFrom(address(this), _receiver, assets);

        /// @dev `_owner` must be solvent
        if (!_isSolventInternal(configData, _borrower, _assetStorage)) revert NotSolvent();

        emit Borrow(_token, _borrower, _receiver, assets, shares);
    }

    function borrow(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _assets,
        address _receiver,
        address _borrower,
        address _spender,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 shares) {
        (, shares) = _borrowInternal(
            _config, _factory, _token, _assets, 0, _receiver, _borrower, _spender, true, _assetStorage
        );
    }

    function maxBorrowShares(
        ISiloConfig _config,
        address _token,
        address _borrower,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 maxShares) {
        (, maxShares) = _maxBorrowInternal(_config, _token, _borrower, _assetStorage);
    }

    function previewBorrowShares(
        ISiloConfig _config,
        address _token,
        uint256 _shares,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        return convertToAssets(_config, _token, _shares, false, true, _assetStorage);
    }

    function borrowShares(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 assets) {
        (assets,) = _borrowInternal(
            _config, _factory, _token, 0, _shares, _receiver, _borrower, _spender, false, _assetStorage
        );
    }

    // solhint-disable-next-line function-max-lines
    function _accrueInterestInternal(
        ISiloConfig.ConfigData memory _configData,
        ISiloFactory _factory,
        address _token,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) private returns (uint256 accruedInterest) {
        uint256 lastTimestamp = _assetStorage[_token].interestRateTimestamp;

        // This is the first time, so we can return early and save some gas
        if (lastTimestamp == 0) {
            _assetStorage[_token].interestRateTimestamp = uint64(block.timestamp);
            return 0;
        }

        // Interest has already been accrued this block
        if (lastTimestamp == block.timestamp) {
            return 0;
        }

        IInterestRateModel model;
        IShareToken collateralToken;

        if (_configData.token0 == _token) {
            model = IInterestRateModel(_configData.interestRateModel0);
            collateralToken = IShareToken(_configData.collateralShareToken0);
        } else if (_configData.token1 == _token) {
            model = IInterestRateModel(_configData.interestRateModel1);
            collateralToken = IShareToken(_configData.collateralShareToken1);
        } else {
            revert WrongToken();
        }

        uint256 rcomp = model.getCompoundInterestRateAndUpdate(_token, block.timestamp);
        // TODO: deployer and DAO fee should be immutable
        uint256 totalFee = _factory.getFee();

        uint256 collateralAssetsCache = _assetStorage[_token].collateralAssets;
        uint256 debtAssetsCache = _assetStorage[_token].debtAssets;
        uint256 daoAndDeployerAmount;
        uint256 depositorsAmount;

        accruedInterest = debtAssetsCache * rcomp / _PRECISION_DECIMALS;

        unchecked {
            // If we overflow on multiplication it should not revert tx, we will get lower fees
            daoAndDeployerAmount = accruedInterest * totalFee / _PRECISION_DECIMALS;
            depositorsAmount = accruedInterest - daoAndDeployerAmount;
        }

        // TODO: should we mint without veSILO notification? It could save significant amount of gas.
        uint256 totalShares = collateralToken.totalSupply();
        uint256 daoAndDeployerShare =
            toShare(daoAndDeployerAmount, collateralAssetsCache + depositorsAmount, totalShares);
        collateralToken.mint(address(_factory), address(this), daoAndDeployerShare);

        // update contract state
        _assetStorage[_token].debtAssets = debtAssetsCache + accruedInterest;
        _assetStorage[_token].collateralAssets = collateralAssetsCache + accruedInterest;
        _assetStorage[_token].interestRateTimestamp = uint64(block.timestamp);
    }

    function accrueInterest(
        ISiloConfig _config,
        ISiloFactory _factory,
        address _token,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 accruedInterest) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        accruedInterest = _accrueInterestInternal(configData, _factory, _token, _assetStorage);
    }
}
