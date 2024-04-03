// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {TokenWithReentrancy} from "silo-core/test/foundry/_mocks/SiloERC4626Lib/TokenWithReentrancy.sol";

import {
    SiloERC4626LibConsumerVulnerable
} from "silo-core/test/foundry/_mocks/SiloERC4626Lib/SiloERC4626LibConsumerVulnerable.sol";

import {
    SiloERC4626LibConsumerNonVulnerable
} from "silo-core/test/foundry/_mocks/SiloERC4626Lib/SiloERC4626LibConsumerNonVulnerable.sol";

// FOUNDRY_PROFILE=core-test forge test -vv --mc ReentrancyOnDepositTest --ffi
contract ReentrancyOnDepositTest is Test {
    SiloERC4626LibConsumerVulnerable internal _vulnerable;
    SiloERC4626LibConsumerNonVulnerable internal _nonVulnerable;

    address internal _token;
    address internal _depositor = makeAddr("_depositor");
    address internal _receiver = makeAddr("_receiver");
    IShareToken internal _shareCollateralToken = IShareToken(makeAddr("_collateralShareToken"));
    IShareToken internal _debtShareToken = IShareToken(makeAddr("_debtShareToken"));

    uint256 internal constant _ASSETS = 100;
    uint256 internal constant _SHARES = 50;

    event SiloAssetState(uint256 assets);

    function setUp() public {
        _vulnerable = new SiloERC4626LibConsumerVulnerable();
        _nonVulnerable = new SiloERC4626LibConsumerNonVulnerable();
        _token = address(new TokenWithReentrancy());

        _mockCalls();
    }

    // solhint-disable-next-line func-name-mixedcase
    function test_SiloERC4626Lib_deposit_vulnerable() public {
        uint256 totalCollateral = _vulnerable.getTotalCollateral();

        // This event is emitted from the reentrancy call.
        // And is triggered by this call:
        // IERC20Upgradeable(_token).safeTransferFrom(_depositor, address(this), assets);
        //
        // As we are testing the vulnerable version of the library,
        // we expect to have the same state as we had before the reentrancy call.
        uint256 expectedCollateral = totalCollateral;

        vm.expectEmit(false, false, false, true);
        emit TokenWithReentrancy.SiloAssetState(expectedCollateral);

        _vulnerable.deposit(
            _token,
            _depositor,
            _ASSETS,
            _SHARES,
            _receiver,
            _shareCollateralToken
        );
    }

    // solhint-disable-next-line func-name-mixedcase
    function test_SiloERC4626Lib_deposit_non_vulnerable() public {
        uint256 totalCollateral = _nonVulnerable.getTotalCollateral();

        // This event is emitted from the reentrancy call.
        // And is triggered by this call:
        // IERC20Upgradeable(_token).safeTransferFrom(_depositor, address(this), assets);
        //
        // As we are testing the non-vulnerable version of the library,
        // we expect to have an updated state during the reentrancy call.
        uint256 expectedCollateral = totalCollateral + _ASSETS;

        vm.expectEmit(false, false, false, true);
        emit TokenWithReentrancy.SiloAssetState(expectedCollateral);

        _nonVulnerable.deposit(
            _token,
            _depositor,
            _ASSETS,
            _SHARES,
            _receiver,
            _shareCollateralToken
        );
    }

    function _mockCalls() internal {
        vm.mockCall(
            address(_shareCollateralToken),
            abi.encodePacked(IERC20.totalSupply.selector),
            abi.encode(1000)
        );

        vm.mockCall(
            address(_shareCollateralToken),
            abi.encodeCall(IShareToken.mint, (_receiver, _depositor, 991)),
            abi.encode(true)
        );
    }
}
