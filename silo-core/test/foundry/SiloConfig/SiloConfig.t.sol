// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISiloConfig, SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

// solhint-disable func-name-mixedcase

/*
forge test -vv --mc SiloConfigTest
*/
contract SiloConfigTest is Test {
    address internal _wrongSilo = makeAddr("wrongSilo");
    address internal _silo0Default = makeAddr("silo0");
    address internal _silo1Default = makeAddr("silo1");

    ISiloConfig.ConfigData internal _configDataDefault0;
    ISiloConfig.ConfigData internal _configDataDefault1;

    SiloConfig internal _siloConfig;

    function setUp() public {
        _configDataDefault0.silo = _silo0Default;
        _configDataDefault0.token = makeAddr("token0");
        _configDataDefault0.debtShareToken = makeAddr("debtShareToken0");

        _configDataDefault1.silo = _silo1Default;
        _configDataDefault1.token = makeAddr("token1");
        _configDataDefault1.debtShareToken = makeAddr("debtShareToken1");

        _siloConfig = siloConfigDeploy(1, _configDataDefault0, _configDataDefault1);

        vm.mockCall(
            _silo0Default,
            abi.encodeCall(
                ISilo.accrueInterestForConfig,
                (_configDataDefault0.interestRateModel, _configDataDefault0.daoFee, _configDataDefault0.deployerFee)
            ),
            abi.encode(true)
        );

        vm.mockCall(
            _silo1Default,
            abi.encodeCall(
                ISilo.accrueInterestForConfig,
                (_configDataDefault1.interestRateModel, _configDataDefault1.daoFee, _configDataDefault1.deployerFee)
            ),
            abi.encode(true)
        );
    }

    function siloConfigDeploy(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public returns (SiloConfig siloConfig) {
        vm.assume(_configData0.silo != _wrongSilo);
        vm.assume(_configData1.silo != _wrongSilo);
        vm.assume(_configData0.silo != _configData1.silo);
        vm.assume(_configData0.daoFee < 0.5e18);
        vm.assume(_configData0.deployerFee < 0.5e18);

        // when using assume, it reject too many inputs
        _configData0.liquidationModule = _configData1.liquidationModule; 
        _configData0.hookReceiver = _configData1.hookReceiver;

        _configData0.otherSilo = _configData1.silo;
        _configData1.otherSilo = _configData0.silo;
        _configData1.daoFee = _configData0.daoFee;
        _configData1.deployerFee = _configData0.deployerFee;

        siloConfig = new SiloConfig(_siloId, _configData0, _configData1);
    }

    /*
    forge test -vv --mt test_daoAndDeployerFeeCap
    */
    function test_daoAndDeployerFeeCap() public {
        ISiloConfig.ConfigData memory _configData0;
        ISiloConfig.ConfigData memory _configData1;

        _configData0.daoFee = 1e18;
        _configData0.deployerFee = 0;

        vm.expectRevert(ISiloConfig.FeeTooHigh.selector);
        new SiloConfig(1, _configData0, _configData1);
    }

    /*
    forge test -vv --mt test_getSilos_fuzz
    */
    function test_getSilos_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        (address silo0, address silo1) = siloConfig.getSilos();
        assertEq(silo0, _configData0.silo);
        assertEq(silo1, _configData1.silo);
    }

    /*
    forge test -vv --mt test_getShareTokens_fuzz
    */
    function test_getShareTokens_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getShareTokens(_wrongSilo);

        (address protectedShareToken, address collateralShareToken, address debtShareToken) = siloConfig.getShareTokens(_configData0.silo);
        assertEq(protectedShareToken, _configData0.protectedShareToken);
        assertEq(collateralShareToken, _configData0.collateralShareToken);
        assertEq(debtShareToken, _configData0.debtShareToken);

        (protectedShareToken, collateralShareToken, debtShareToken) = siloConfig.getShareTokens(_configData1.silo);
        assertEq(protectedShareToken, _configData1.protectedShareToken);
        assertEq(collateralShareToken, _configData1.collateralShareToken);
        assertEq(debtShareToken, _configData1.debtShareToken);
    }

    /*
    forge test -vv --mt test_getAssetForSilo_fuzz
    */
    function test_getAssetForSilo_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getAssetForSilo(_wrongSilo);

        assertEq(siloConfig.getAssetForSilo(_configData0.silo), _configData0.token);
        assertEq(siloConfig.getAssetForSilo(_configData1.silo), _configData1.token);
    }

    /*
    forge test -vv --mt test_getConfigs_fuzz
    */
    function test_getConfigs_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getConfigs(_wrongSilo, address(0), 0 /* always 0 for external calls */);

        (
            ISiloConfig.ConfigData memory c0,
            ISiloConfig.ConfigData memory c1,
        ) = siloConfig.getConfigs(_configData0.silo, address(0), 0 /* always 0 for external calls */);

        assertEq(keccak256(abi.encode(c0)), keccak256(abi.encode(_configData0)));
        assertEq(keccak256(abi.encode(c1)), keccak256(abi.encode(_configData1)));
    }

    /*
    forge test -vv --mt test_getConfig_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 3
    function test_getConfig_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        // we always using #0 setup for hookReceiver
        _configData1.hookReceiver = _configData0.hookReceiver;

        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getConfig(_wrongSilo);

        ISiloConfig.ConfigData memory c0 = siloConfig.getConfig(_configData0.silo);
        assertEq(keccak256(abi.encode(c0)), keccak256(abi.encode(_configData0)), "expect config for silo0");

        ISiloConfig.ConfigData memory c1 = siloConfig.getConfig(_configData1.silo);
        assertEq(keccak256(abi.encode(c1)), keccak256(abi.encode(_configData1)), "expect config for silo1");
    }

    /*
    forge test -vv --mt test_getFeesWithAsset_fuzz
    */
    function test_getFeesWithAsset_fuzz(
        uint256 _siloId,
        ISiloConfig.ConfigData memory _configData0,
        ISiloConfig.ConfigData memory _configData1
    ) public {
        SiloConfig siloConfig = siloConfigDeploy(_siloId, _configData0, _configData1);

        vm.expectRevert(ISiloConfig.WrongSilo.selector);
        siloConfig.getFeesWithAsset(_wrongSilo);

        (uint256 daoFee, uint256 deployerFee, uint256 flashloanFee, address asset) = siloConfig.getFeesWithAsset(_configData0.silo);

        assertEq(daoFee, _configData0.daoFee);
        assertEq(deployerFee, _configData0.deployerFee);
        assertEq(flashloanFee, _configData0.flashloanFee);
        assertEq(asset, _configData0.token);

        (daoFee, deployerFee, flashloanFee, asset) = siloConfig.getFeesWithAsset(_configData1.silo);

        assertEq(daoFee, _configData1.daoFee);
        assertEq(deployerFee, _configData1.deployerFee);
        assertEq(flashloanFee, _configData1.flashloanFee);
        assertEq(asset, _configData1.token);
    }

    /*
    forge test -vv --mt test_openDebt_revertOnOnlySilo
    */
    function test_openDebt_revertOnOnlySilo() public {
        vm.expectRevert(ISiloConfig.OnlySilo.selector);
        _siloConfig.accrueInterestAndGetConfigs(makeAddr("SomeSilo"), makeAddr("Borrower"), Hook.BORROW);
    }

    /*
    forge test -vv --mt test_openDebt_pass
    */
    function test_openDebt_pass() public {
        vm.prank(_silo0Default);
        _siloConfig.accrueInterestAndGetConfigs(_silo0Default, makeAddr("Borrower 1"), Hook.BORROW);

        vm.prank(_silo0Default);
        _siloConfig.crossNonReentrantAfter();

        vm.prank(_silo1Default);
        _siloConfig.accrueInterestAndGetConfigs(_silo1Default, makeAddr("Borrower 2"), Hook.BORROW);

        vm.prank(_silo1Default);
        _siloConfig.crossNonReentrantAfter();
    }

    /*
    forge test -vv --mt test_getConfigs_zero
    */
    function test_getConfigs_zero() public {
        address silo = _silo0Default;

        (
            ISiloConfig.ConfigData memory siloConfig,
            ISiloConfig.ConfigData memory otherSiloConfig,
            ISiloConfig.DebtInfo memory debtInfo
        ) = _siloConfig.getConfigs(silo, address(0), 0 /* always 0 for external calls */);

        ISiloConfig.DebtInfo memory emptyDebtInfo;

        assertEq(siloConfig.silo, silo, "first config should be for silo");
        assertEq(otherSiloConfig.silo, _silo1Default);
        assertEq(abi.encode(emptyDebtInfo), abi.encode(debtInfo), "debtInfo should be empty");
    }

    /*
    forge test -vv --mt test_openDebt_skipsIfAlreadyOpen
    */
    function test_openDebt_skipsIfAlreadyOpen() public {    
        address borrower = makeAddr("borrower");

        vm.prank(_silo0Default);
        (,, ISiloConfig.DebtInfo memory debtInfo1) = _siloConfig.accrueInterestAndGetConfigs(
            _silo0Default,
            borrower,
            Hook.BORROW
        );

        vm.prank(_silo0Default);
        _siloConfig.crossNonReentrantAfter();

        vm.prank(_silo0Default);
        (,, ISiloConfig.DebtInfo memory debtInfo2) = _siloConfig.accrueInterestAndGetConfigs(
            _silo0Default,
            borrower,
            Hook.BORROW
        );

        assertEq(abi.encode(debtInfo1), abi.encode(debtInfo2), "nothing should change");
    }

    /*
    forge test -vv --mt test_openDebt_debtInThisSilo
    */
    function test_openDebt_debtInThisSilo() public {
        address borrower = makeAddr("borrower");

        vm.prank(_silo0Default);
        (,, ISiloConfig.DebtInfo memory debtInfo) = _siloConfig.accrueInterestAndGetConfigs(
            _silo0Default,
            borrower,
            Hook.BORROW | Hook.SAME_ASSET
        );

        assertTrue(debtInfo.debtPresent);
        assertTrue(debtInfo.sameAsset);
        assertTrue(debtInfo.debtInSilo0);
        assertTrue(debtInfo.debtInThisSilo);
    }

    /*
    forge test -vv --mt test_openDebt_debtInOtherSilo
    */
    function test_openDebt_debtInOtherSilo() public {
        address borrower = makeAddr("borrower");

        vm.prank(_silo1Default);
        _siloConfig.accrueInterestAndGetConfigs(_silo1Default, borrower, Hook.BORROW);

        vm.prank(_silo1Default);
        _siloConfig.crossNonReentrantAfter();

        (,, ISiloConfig.DebtInfo memory debtInfo) = _siloConfig.getConfigs(_silo0Default, borrower, Hook.BORROW);

        assertTrue(debtInfo.debtPresent);
        assertTrue(!debtInfo.sameAsset);
        assertTrue(!debtInfo.debtInSilo0);
        assertTrue(!debtInfo.debtInThisSilo);

        (,, debtInfo) = _siloConfig.getConfigs(_silo1Default, address(1), 0 /* always 0 for external calls */);
        ISiloConfig.DebtInfo memory emptyDebtInfo;

        assertEq(abi.encode(emptyDebtInfo), abi.encode(debtInfo), "debtInfo should be empty");
    }

    /*
    forge test -vv --mt test_onDebtTransfer_clone
    */
    /// forge-config: core-test.fuzz.runs = 10
    function test_onDebtTransfer_clone(bool _silo0, bool sameAsset) public {
        address silo = _silo0 ? _silo0Default : _silo1Default;
        uint256 action = sameAsset ? Hook.BORROW | Hook.SAME_ASSET : Hook.BORROW;

        address from = makeAddr("from");
        address to = makeAddr("to");

        vm.prank(silo);
        (,, ISiloConfig.DebtInfo memory debtInfoFrom) = _siloConfig.accrueInterestAndGetConfigs(
            silo,
            from,
            action
        );

        vm.prank(_silo0 ? _configDataDefault0.debtShareToken : _configDataDefault1.debtShareToken);
        _siloConfig.onDebtTransfer(from, to);

        (
            ,, ISiloConfig.DebtInfo memory debtInfoTo
        ) = _siloConfig.getConfigs(silo, to, 0 /* always 0 for external calls */);

        assertEq(abi.encode(debtInfoFrom), abi.encode(debtInfoTo), "debt should be same if called for same silo");
    }

    /*
    forge test -vv --mt test_onDebtTransfer_revertIfNotDebtToken
    */
    function test_onDebtTransfer_revertIfNotDebtToken() public {
        address silo = makeAddr("siloX");
        address from = makeAddr("from");
        address to = makeAddr("to");

        vm.prank(silo);
        vm.expectRevert(ISiloConfig.OnlyDebtShareToken.selector);
        _siloConfig.onDebtTransfer(from, to);
    }

    /*
    forge test -vv --mt test_onDebtTransfer_DebtExistInOtherSilo
    */
    function test_onDebtTransfer_DebtExistInOtherSilo() public {
        address from = makeAddr("from");
        address to = makeAddr("to");

        vm.prank(_silo0Default);
        _siloConfig.accrueInterestAndGetConfigs(
            _silo0Default,
            from,
            Hook.BORROW | Hook.SAME_ASSET
        );

        vm.prank(_silo0Default);
        _siloConfig.crossNonReentrantAfter();

        vm.prank(_silo1Default);
        _siloConfig.accrueInterestAndGetConfigs(
            _silo1Default,
            to,
            Hook.BORROW | Hook.SAME_ASSET
        );

        vm.prank(_silo1Default);
        _siloConfig.crossNonReentrantAfter();

        vm.prank(_configDataDefault0.debtShareToken);
        vm.expectRevert(ISiloConfig.DebtExistInOtherSilo.selector);
        _siloConfig.onDebtTransfer(from, to);

        vm.prank(_configDataDefault0.debtShareToken);
        // this will pass, because `from` has debt in 0
        _siloConfig.onDebtTransfer(to, from);

        vm.prank(_configDataDefault1.debtShareToken);
        // this will pass, because `to` has debt in 1
        _siloConfig.onDebtTransfer(from, to);

        vm.prank(_configDataDefault1.debtShareToken);
        vm.expectRevert(ISiloConfig.DebtExistInOtherSilo.selector);
        _siloConfig.onDebtTransfer(to, from);
    }

    /*
    forge test -vv --mt test_onDebtTransfer_pass
    */
    function test_onDebtTransfer_pass() public {
        address from = makeAddr("from");
        address to = makeAddr("to");

        vm.prank(_silo0Default);
        _siloConfig.accrueInterestAndGetConfigs(
            _silo0Default,
            from,
            Hook.BORROW | Hook.SAME_ASSET
        );

        vm.prank(_silo0Default);
        _siloConfig.crossNonReentrantAfter();

        vm.prank(_silo0Default);
        _siloConfig.accrueInterestAndGetConfigs(
            _silo0Default,
            to,
            Hook.BORROW
        );

        vm.prank(_silo0Default);
        _siloConfig.crossNonReentrantAfter();

        vm.prank(_configDataDefault0.debtShareToken);
        _siloConfig.onDebtTransfer(from, to);

        (
            ,, ISiloConfig.DebtInfo memory debtInfoTo
        ) = _siloConfig.getConfigs(_silo1Default, to, 0 /* always 0 for external calls */);

        assertTrue(debtInfoTo.debtPresent, "debtPresent");
        assertTrue(!debtInfoTo.sameAsset, "sameAsset is not cloned when debt already open");
        assertTrue(debtInfoTo.debtInSilo0, "debtInSilo0");
        assertTrue(!debtInfoTo.debtInThisSilo, "call is from silo1, so debt should not be in THIS silo");
    }

    /*
    forge test -vv --mt test_closeDebt_revert
    */
    function test_closeDebt_OnlySiloOrDebtShareToken() public {
        vm.expectRevert(ISiloConfig.OnlySiloOrDebtShareToken.selector);
        _siloConfig.closeDebt(address(0));
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --mt test_closeDebt_pass
    */
    function test_closeDebt_pass() public {
        address borrower = makeAddr("borrower");

        vm.prank(_silo1Default);
        _siloConfig.accrueInterestAndGetConfigs(
            _silo1Default,
            borrower,
            Hook.BORROW | Hook.SAME_ASSET
        );

        vm.prank(_silo1Default);
        _siloConfig.crossNonReentrantAfter();

        vm.prank(_silo0Default); // other silo can close debt
        _siloConfig.closeDebt(borrower);

        ISiloConfig.DebtInfo memory emptyDebtInfo;
        (
            ,, ISiloConfig.DebtInfo memory debt
        ) = _siloConfig.getConfigs(_silo1Default, borrower, 0 /* always 0 for external calls */);

        assertEq(abi.encode(emptyDebtInfo), abi.encode(debt), "debt should be deleted");
    }
}
