// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc DepositTest
*/
contract DepositTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    MintableToken weth;
    MintableToken usdc;

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event DepositProtected(address indexed sender, address indexed owner, uint256 assets, uint256 shares);


    function setUp() public {
        siloConfig = _setUpLocalFixture();

        weth = token0;
        usdc = token1;
    }

    /*
    forge test -vv --ffi --mt test_deposit_revertsZeroAssets
    */
    function test_deposit_revertsZeroAssets() public {
        uint256 _assets;
        ISilo.AssetType _type;
        address _depositor = makeAddr("Depositor");

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.deposit(_assets, _depositor);

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.deposit(_assets, _depositor, _type);
    }

    /*
    forge test -vv --ffi --mt test_deposit_reverts_WrongAssetType
    */
    function test_deposit_reverts_WrongAssetType() public {
        uint256 _assets = 1;
        ISilo.AssetType _type = ISilo.AssetType.Debt;
        address _depositor = makeAddr("Depositor");

        vm.expectRevert(ISilo.WrongAssetType.selector);
        silo0.deposit(_assets, _depositor, _type);
    }

    /*
    forge test -vv --ffi --mt test_deposit_everywhere
    */
    function test_deposit_everywhere() public {
        uint256 assets = 1;
        address depositor = makeAddr("Depositor");

        _makeDeposit(silo0, token0, assets, depositor, ISilo.AssetType.Collateral);
        _makeDeposit(silo0, token0, assets, depositor, ISilo.AssetType.Protected);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.AssetType.Collateral);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.AssetType.Protected);

        (ISiloConfig.ConfigData memory collateral, ISiloConfig.ConfigData memory debt) = siloConfig.getConfigs(address(silo0));

        assertEq(token0.balanceOf(address(silo0)), assets * 2);
        assertEq(silo0.getCollateralAssets(), assets);
        assertEq(silo0.getProtectedAssets(), assets);
        assertEq(silo0.getDebtAssets(), 0);

        assertEq(IShareToken(collateral.collateralShareToken).balanceOf(depositor), assets, "collateral shares");
        assertEq(IShareToken(collateral.protectedShareToken).balanceOf(depositor), assets, "protected shares");

        assertEq(token1.balanceOf(address(silo1)), assets * 2);
        assertEq(silo1.getCollateralAssets(), assets);
        assertEq(silo1.getProtectedAssets(), assets);
        assertEq(silo1.getDebtAssets(), 0);

        assertEq(IShareToken(debt.collateralShareToken).balanceOf(depositor), assets, "collateral shares (on other silo)");
        assertEq(IShareToken(debt.protectedShareToken).balanceOf(depositor), assets, "protected shares (on other silo)");
    }

    /*
    forge test -vv --ffi --mt test_deposit_toWrongSilo
    */
    function test_deposit_toWrongSilo() public {
        uint256 assets = 1;
        address depositor = makeAddr("Depositor");

        vm.prank(depositor);
        token1.approve(address(silo0), assets);
        vm.prank(depositor);
        vm.expectRevert("ERC20: insufficient allowance");
        silo0.deposit(assets, depositor, ISilo.AssetType.Collateral);
    }

    /*
    forge test -vv --ffi --mt test_deposit_emitEvents
    */
    function test_deposit_emitEvents() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");

        token0.mint(depositor, assets * 2);
        vm.prank(depositor);
        token0.approve(address(silo0), assets * 2);

        vm.expectEmit(true, true, true, true);
        emit Deposit(depositor, depositor, assets, assets);

        vm.prank(depositor);
        silo0.deposit(assets, depositor, ISilo.AssetType.Collateral);

        vm.expectEmit(true, true, true, true);
        emit DepositProtected(depositor, depositor, assets, assets);

        vm.prank(depositor);
        silo0.deposit(assets, depositor, ISilo.AssetType.Protected);
    }

    /*
    forge test -vv --ffi --mt test_deposit_totalAssets
    */
    function test_deposit_totalAssets() public {
        _deposit(123, makeAddr("Depositor"));

        assertEq(silo0.totalAssets(), 123, "totalAssets 0");
        assertEq(silo1.totalAssets(), 0, "totalAssets 1");
    }

    /*
    forge test -vv --ffi --mt test_maxDeposit
    */
    function test_maxDeposit() public {
        assertEq(silo0.maxDeposit(address(1)), 2 ** 256 - 1, "ERC4626 expect to return 2 ** 256 - 1");
        assertEq(silo0.maxMint(address(1)), 2 ** 256 - 1, "ERC4626 expect to return 2 ** 256 - 1 (maxMint)");
    }
}
