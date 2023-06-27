// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";

import "./external/libraries/Math.sol";
import "./external/UniswapV2ERC20.sol";

import "./interfaces/NotSupportedInPair.sol";
import "./AmmStateModel.sol";
import "./AmmPriceModel.sol";
import "./utils/SafeTransfers.sol";


contract SiloAmmPair is NotSupportedInPair, SafeTransfers, UniswapV2ERC20, AmmStateModel, AmmPriceModel {
    // TODO when we check exponential operations on shares we will decide if we need minimum liquidity
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    /// @dev _TOKEN_0 < _TOKEN_1
    address internal immutable _TOKEN_0; // solhint-disable-line var-name-mixedcase
    address internal immutable _TOKEN_1; // solhint-disable-line var-name-mixedcase

    /// @dev gives token0 price in token1
    ISiloOracle public immutable ORACLE_0; // solhint-disable-line var-name-mixedcase
    ISiloOracle public immutable ORACLE_1; // solhint-disable-line var-name-mixedcase

    /// @dev address of Silo with witch we cresting 1:1 bond for liquidity management
    address internal immutable _SILO; // solhint-disable-line var-name-mixedcase

    address internal immutable _FEE_TO; // solhint-disable-line var-name-mixedcase

    address internal immutable _ROUTER; // solhint-disable-line var-name-mixedcase

    /// @dev flag, that tell us, if we have two oracle set up or one
    OracleSetup immutable private _ORACLE_SETUP; // solhint-disable-line var-name-mixedcase

    uint112 internal _token0Reserve;           // uses single storage slot, accessible via getReserves
    uint112 internal _token1Reserve;           // uses single storage slot, accessible via getReserves

    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint256 private _unlocked = 1;

    modifier lock() {
        if (_unlocked == 0) revert LOCKED();
        _unlocked = 0;
        _;
        _unlocked = 1;
    }

    modifier onlySilo() {
        if (msg.sender != _SILO) revert ONLY_SILO();
        _;
    }

    /// @dev tokens must be sorted
    constructor(
        address _router,
        address _silo,
        address _token0,
        address _token1,
        ISiloOracle _oracle0,
        ISiloOracle _oracle1,
        AmmPriceConfig memory _config
    )
        AmmPriceModel(_config)
    {
        // tokens verification is done by silo
        _TOKEN_0 = _token0;
        _TOKEN_1 = _token1;

        if (_router == address(0)) revert ZERO_ADDRESS();
        // zero check is enough, we don't need to check, if this is real silo
        if (_silo == address(0)) revert ZERO_ADDRESS();

        _ROUTER = _router;
        _SILO = _silo;

        // TODO
        _FEE_TO = address(0);

        ORACLE_0 = _oracle0;
        ORACLE_1 = _oracle1;

        _ORACLE_SETUP = _oracleSetup(address(_oracle0), address(_oracle1));
    }

    /// @inheritdoc ISiloAmmPair
    function addLiquidity(
        address _collateral,
        address _user,
        bool _cleanUp,
        uint256 _collateralAmount,
        uint256 _collateralValue
    )
        external
        virtual
        onlySilo
        returns (uint256 shares)
    {
        if (_cleanUp) {
            removeLiquidity(_collateral, _user, ONE);
        }

        shares = _stateChangeOnAddLiquidity(_collateral, _user, _collateralAmount, _collateralValue);
        if (shares == 0) revert ZERO_SHARES();

        _priceInit(_collateral);
        _priceChangeOnAddingLiquidity(_collateral);
    }

    /// @inheritdoc IUniswapV2Pair
    function swap(uint256 _amount0Out, uint256 _amount1Out, address _to, bytes calldata _data)
        external
        virtual
        lock
        returns (uint256 amountIn)
    {
        if (_amount0Out == 0 && _amount1Out == 0) revert INSUFFICIENT_OUTPUT_AMOUNT();
        if (_amount0Out != 0 && _amount1Out != 0) revert INVALID_OUT();
        if (_to == _TOKEN_0 || _to == _TOKEN_1) revert INVALID_TO();

        bool token0In = _amount0Out == 0;

        // collateral is always the one, that will be OUT of the pool
        (address collateral, address debtToken, uint256 collateralOut) = token0In
            ? (_TOKEN_1, _TOKEN_0, _amount1Out)
            : (_TOKEN_0, _TOKEN_1, _amount0Out);

        uint256 k = _onSwapCalculateK(collateral);
        _onSwapPriceChange(collateral, uint64(k));

        uint256 collateralPriceInDebt = getPriceFromOracle(collateral, collateralOut);
        amountIn = getDebtIn(collateralPriceInDebt, k);
        if (amountIn == 0) revert INSUFFICIENT_INPUT_AMOUNT();

        _finishSwap(collateral, debtToken, token0In, amountIn, collateralOut, _to, _data);
    }

    /// @inheritdoc ISiloAmmPair
    function exactInSwap(address _tokenIn, uint256 _amountIn, address _to, bytes calldata _data)
        external
        virtual
        lock
        returns (uint256 amountOut)
    {
        if (_amountIn == 0) revert INSUFFICIENT_INPUT_AMOUNT();
        if (_to == _TOKEN_0 || _to == _TOKEN_1) revert INVALID_TO();

        bool token0In = _tokenIn == _TOKEN_0;

        // collateral is always the one, that will be OUT of the pool
        address collateral = token0In ? _TOKEN_1 : _TOKEN_0;

        uint256 k = _onSwapCalculateK(collateral);
        _onSwapPriceChange(collateral, uint64(k));

        // REVERSE calculation of what we have in `swap`
        uint256 collateralPriceInDebt = getCollateralOut(_amountIn, k);
        amountOut = getPriceFromOracle(_tokenIn, collateralPriceInDebt);
        if (amountOut == 0) revert INSUFFICIENT_OUTPUT_AMOUNT();

        _finishSwap(collateral, _tokenIn, token0In, _amountIn, amountOut, _to, _data);
    }

    /// @dev this is only for backward compatibility with uniswapV2
    /// @return router address in returned, because in our case, router takes over factory interface
    function factory() external view returns (address) {
        return _ROUTER;
    }

    function silo() external view returns (address) {
        return _SILO;
    }

    function token0() external view returns (address) {
        return _TOKEN_0;
    }

    function token1() external view returns (address) {
        return _TOKEN_1;
    }

    function feeTo() external view returns (address) {
        return _FEE_TO;
    }

    /// @inheritdoc ISiloAmmPair
    function removeLiquidity(address _collateral, address _user, uint256 _w)
        public
        virtual
        onlySilo
        returns (uint256 debtAmount)
    {
        if (_w > ONE) revert PERCENT_OVERFLOW();

        debtAmount = _w == ONE
            ? _withdrawAllLiquidity(_collateral, _user)
            : _withdrawLiquidity(_collateral, _user, _w);

        _priceChangeOnWithdraw(_collateral);
    }

    /// @return reserve0
    /// @return reserve1
    /// @return blockTimestampLast is always 0, we do not support Oracle functionality
    function getReserves() public view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        // TODO if univ2 can handle reserves in uint112 then maybe so do we? QA and verify
        reserve0 = uint112(_totalStates[_TOKEN_0].collateralAmount);
        reserve1 = uint112(_totalStates[_TOKEN_1].collateralAmount);
        blockTimestampLast = 0;
    }

    // TODO once Edd has code we can complete that logic
    /// @return quotePrice price of base token denominated in other token
    function getPriceFromOracle(address _baseToken, uint256 _baseAmount)
        public
        view
        virtual
        returns (uint256 quotePrice)
    {
        if (_ORACLE_SETUP == OracleSetup.BOTH) {
            //
        } else if (_ORACLE_SETUP == OracleSetup.NONE) {
            // if (ORACLE_0 == 0 && ORACLE_1 == 0) return _collateralAmount; do we support this case?
            return _baseAmount; // TODO temporary solution
        } else if (_ORACLE_SETUP == OracleSetup.FOR_TOKEN0) {
            if (_baseToken == _TOKEN_0) {
                // we have only one oracle and it is for our `_collateral` so this case is straight forward
                quotePrice = ORACLE_0.quoteView(_baseAmount, _TOKEN_0); // return price in _TOKEN_1
            } else {
                // we have only one oracle, but is not set for `_collateral` token, but for other one
                // so lal we need to change base? => so we can simply remove this last if?
                // and it does not matter for which token is is set as always using this oracle for both tokens?
                quotePrice = ORACLE_0.quoteView(_baseAmount, _TOKEN_1);
            }
        }
    }

    function _finishSwap(
        address _collateral,
        address _debt,
        bool _token0In,
        uint256 _amountIn,
        uint256 _amountOut,
        address _to,
        bytes calldata _data
    )
        internal
        virtual
    {
        _onSwapStateChange(_collateral, _amountOut, _amountIn);

        if (_token0In) {
            emit Swap(msg.sender, _amountIn, uint256(0), uint256(0), _amountOut, _to);
        } else {
            emit Swap(msg.sender, uint256(0), _amountIn, _amountOut, uint256(0), _to);
        }

        // we doing transfer directly to SILO, but state will be updated on withdraw
        _safeTransferFrom(_debt, msg.sender, _SILO, _amountIn);
        _safeTransferFrom(_collateral, _SILO, _to, _amountOut);

        if (_data.length != 0) {
            // keep it for backwards compatibility and allow flash swap
            (uint256 _amount0Out, uint256 _amount1Out) = _token0In
                ? (uint256(0), _amountOut)
                : (_amountOut, uint256(0));

            IUniswapV2Callee(_to).uniswapV2Call(msg.sender, _amount0Out, _amount1Out, _data);
        }
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) internal returns (bool feeOn) {
        feeOn = _FEE_TO != address(0);
        uint _kLast = kLast; // gas savings

        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint rootKLast = Math.sqrt(_kLast);

                if (rootK > rootKLast) {
                    uint numerator = totalSupply * (rootK - rootKLast);
                    uint denominator = rootK * 5 + rootKLast;
                    uint liquidity;
                    unchecked { liquidity = numerator / denominator; }

                    if (liquidity != 0) _mint(_FEE_TO, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function _oracleSetup(address _oracle0, address _oracle1) internal pure returns (OracleSetup) {
        if (_oracle0 == address(0) && _oracle1 == address(0)) return OracleSetup.NONE;
        if (_oracle0 != address(0) && _oracle1 != address(0)) return OracleSetup.BOTH;
        if (_oracle0 == address(0)) return OracleSetup.FOR_TOKEN1;

        return OracleSetup.FOR_TOKEN0;
    }
}
