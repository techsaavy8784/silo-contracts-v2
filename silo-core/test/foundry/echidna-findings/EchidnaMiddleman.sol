// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {PartialLiquidationLib} from "silo-core/contracts/liquidation/lib/PartialLiquidationLib.sol";

import {EchidnaSetup} from "./EchidnaSetup.sol";
import {MintableToken} from "../_common/MintableToken.sol";

contract EchidnaMiddleman is EchidnaSetup {
    using SiloLensLib for ISilo;

    function __depositNeverMintsZeroShares(uint8 _actor, bool _siloZero, uint256 _amount) internal {
        emit log_named_string("    function", "__depositNeverMintsZeroShares");

        address actor = _chooseActor(_actor);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.deposit(_amount, actor);
    }

    function __borrow(uint8 _actor, bool _siloZero, uint256 _amount) internal {
        emit log_named_string("    function", "__borrow");

        address actor = _chooseActor(_actor);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.borrow(_amount, actor, actor, false /* sameAsset */);
    }

    function __previewDeposit_doesNotReturnMoreThanDeposit(uint8 _actor, uint256 _assets)
        internal
        returns (uint256 shares)
    {
        emit log_named_string("    function", "__previewDeposit_doesNotReturnMoreThanDeposit");

        address actor = _chooseActor(_actor);
        vm.startPrank(actor);

        uint256 depositShares = silo0.previewDeposit(_assets);
        shares = silo0.deposit(_assets, actor);
        assertEq(depositShares, shares, "previewDeposit fail");

        vm.stopPrank();
    }

    function __maxBorrow_correctReturnValue(uint8 _actor) internal returns (uint256 maxAssets, uint256 shares) {
        emit log_named_string("    function", "__maxBorrow_correctReturnValue");

        address actor = _chooseActor(_actor);
        maxAssets = silo0.maxBorrow(actor, false /* sameAsset */);

        vm.prank(actor);
        shares = silo0.borrow(maxAssets, actor, actor, false /* sameAsset */); // should not revert!
    }

    function __mint(uint8 _actor, bool _siloZero, uint256 _shares) internal {
        emit log_named_string("    function", "__mint");

        address actor = _chooseActor(_actor);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.mint(_shares, actor);
    }

    function __maxBorrowShares_correctReturnValue(uint8 _actor) internal returns (uint256 maxBorrow, uint256 shares) {
        emit log_named_string("    function", "__maxBorrowShares_correctReturnValue");

        address actor = _chooseActor(_actor);

        maxBorrow = silo0.maxBorrowShares(actor, false /* sameAsset */);
        assertGt(maxBorrow, 0, "in echidna scenarios we exclude zeros, so we should not get it here as well");

        vm.prank(actor);
        shares = silo0.borrowShares(maxBorrow, actor, actor, false /* sameAsset */);
    }

    function __maxLiquidation_correctReturnValue(uint8 _actor) internal {
        emit log_named_string("    function", "__maxLiquidation_correctReturnValue");

        address actor = _chooseActor(_actor);

        (bool isSolvent, ISilo siloWithDebt, ) = _invariant_insolventHasDebt(actor);
        assertFalse(isSolvent, "expect not solvent user");

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(siloWithDebt), actor);

        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));

        __prepareForLiquidationRepay(siloWithDebt, actor, debtToRepay);

        vm.prank(actor);
        partialLiquidation.liquidationCall(address(siloWithDebt), debt, collateral, actor, debtToRepay, false);
    }

    function __maxWithdraw_correctMax(uint8 _actor) internal {
        emit log_named_string("    function", "__maxWithdraw_correctMax");

        address actor = _chooseActor(_actor);

        (, ISilo _siloWithCollateral) = _invariant_onlySolventUserCanRedeem(actor);
        _requireHealthySilo(_siloWithCollateral);

        uint256 maxWithdraw = _siloWithCollateral.maxWithdraw(actor);
        emit log_named_decimal_uint("maxWithdraw", maxWithdraw, 18);

        vm.prank(actor);
        _siloWithCollateral.withdraw(maxWithdraw, actor, actor);
    }

    function __deposit(uint8 _actor, bool _siloZero, uint256 _amount) internal {
        emit log_named_string("    function", "__deposit");

        address actor = _chooseActor(_actor);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.deposit(_amount, actor);
    }

    function __transitionCollateral_doesNotResultInMoreShares(
        uint8 _actor,
        bool _siloZero,
        uint256 _amount,
        uint8 _type
    ) internal returns (uint256 transitionedAssets) {
        emit log_named_string("    function", "__transitionCollateral_doesNotResultInMoreShares");

        address actor = _chooseActor(_actor);

        ISilo vault = __chooseSilo(_siloZero);
        _invariant_checkForInterest(vault);

        (address protected, address collateral, ) = siloConfig.getShareTokens(address(vault));

        uint256 previewAssetsSumBefore;

//        bool noInterest = _checkForInterest(vault);
        uint256 protBalanceBefore = IShareToken(protected).balanceOf(address(actor));
        uint256 collBalanceBefore = IShareToken(collateral).balanceOf(address(actor));

        { // too deep
            uint256 previewCollateralBefore = vault.previewRedeem(collBalanceBefore, ISilo.CollateralType.Collateral);
            uint256 previewProtectedBefore = vault.previewRedeem(protBalanceBefore, ISilo.CollateralType.Protected);

            previewAssetsSumBefore = previewCollateralBefore + previewProtectedBefore;
        }

        vm.prank(actor);
        transitionedAssets = vault.transitionCollateral(_amount, actor, ISilo.CollateralType(_type));

        uint256 protBalanceAfter = IShareToken(protected).balanceOf(address(actor));
        uint256 collBalanceAfter = IShareToken(collateral).balanceOf(address(actor));

        { // too deep
            uint256 previewCollateralAfter = vault.previewRedeem(collBalanceAfter, ISilo.CollateralType.Collateral);
            uint256 previewProtectedAfter = vault.previewRedeem(protBalanceAfter, ISilo.CollateralType.Protected);
            uint256 previewAssetsSumAfter = previewCollateralAfter + previewProtectedAfter;

            assertGe(previewAssetsSumBefore, previewAssetsSumAfter, "price is flat, so there should be no gains (we accept 1 wei diff)");
            assertLe(previewAssetsSumBefore - previewAssetsSumAfter, 1, "we accept 1 wei diff");
        }

        { // too deep
            // note: this could result in false positives due to interest calculation, and differences between
            // protected and unprotected shares/balances. Another way to check this property would be to
            // transitionCollateral in one direction, and then in the opposite direction, and only check shares/assets
            // after the second transition.

            emit log("transition back");

            // transition back, so we can verify number of shares
            // when used input _amount, I'm getting: NotEnoughLiquidity()
            emit log_named_uint("protected).balanceOf", IShareToken(protected).balanceOf(address(actor)));
            emit log_named_uint("protected).balanceOf", IShareToken(collateral).balanceOf(address(actor)));
            emit log_named_uint("shares", _amount);

            (uint256 sharesTransitioned, ISilo.CollateralType _withdrawType) =
                _type == uint8(ISilo.CollateralType.Collateral)
                    ? (protBalanceAfter - protBalanceBefore, ISilo.CollateralType.Protected)
                    : (collBalanceAfter - collBalanceBefore, ISilo.CollateralType.Collateral);

            vm.prank(actor);
            transitionedAssets = vault.transitionCollateral(sharesTransitioned, actor, _withdrawType);

            protBalanceAfter = IShareToken(protected).balanceOf(address(actor));
            collBalanceAfter = IShareToken(collateral).balanceOf(address(actor));

            assertLe(
                protBalanceBefore - protBalanceAfter,
                1,
                "[protected] there should be no gain in shares, accepting 1 wei loss because of rounding"
            );

            assertLe(
                collBalanceBefore - collBalanceAfter,
                1,
                "[collateral] there should be no gain in shares, accepting 1 wei loss because of rounding"
            );
        }
    }

    function __cannotPreventInsolventUserFromBeingLiquidated(uint8 _actor, bool _receiveShares) internal {
        emit log_named_string("    function", "__cannotPreventInsolventUserFromBeingLiquidated");

        address actor = _chooseActor(_actor);

        (bool isSolvent, ISilo siloWithDebt,) = _invariant_insolventHasDebt(actor);
        assertFalse(isSolvent, "expect not solvent user");

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(siloWithDebt), actor);
        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));

        __prepareForLiquidationRepay(siloWithDebt, actor, debtToRepay);

        vm.prank(actor);
        partialLiquidation.liquidationCall(address(siloWithDebt), debt, collateral, actor, debtToRepay, _receiveShares);
    }

    function __debtSharesNeverLargerThanDebt() internal {
        emit log_named_string("    function", "__debtSharesNeverLargerThanDebt");

        uint256 debt0 = silo0.getDebtAssets();
        uint256 debt1 = silo1.getDebtAssets();

        (, , address debtShareToken0) = siloConfig.getShareTokens(address(silo0));
        (, , address debtShareToken1) = siloConfig.getShareTokens(address(silo1));

        uint256 debtShareBalance0 = IShareToken(debtShareToken0).totalSupply();
        uint256 debtShareBalance1 = IShareToken(debtShareToken1).totalSupply();

        assertGe(debt0, debtShareBalance0, "[debt] assets0 must be >= shares0");
        assertGe(debt1, debtShareBalance1, "[debt] assets1 must be >= shares1");
    }

    function __borrowShares(uint8 _actorIndex, bool _siloZero, uint256 _shares) internal {
        emit log_named_string("    function", "__borrowShares");

        address actor = _chooseActor(_actorIndex);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.borrowShares(_shares, actor, actor, false /* sameAsset */);
    }

    function __maxRedeem_correctMax(uint8 _actorIndex) internal {
        emit log_named_string("    function", "__maxRedeem_correctMax");

        address actor = _chooseActor(_actorIndex);

        (, ISilo _siloWithCollateral) = _invariant_onlySolventUserCanRedeem(actor);
        _requireHealthySilos();

        // you can redeem where there is no debt
        uint256 maxShares = _siloWithCollateral.maxRedeem(address(actor));
        assertGt(maxShares, 0, "Zero shares to withdraw");

        emit log_named_decimal_uint("Max Shares to redeem", maxShares, 18);

        vm.prank(actor);
        _siloWithCollateral.redeem(maxShares, actor, actor); // expect not to fail!
    }

    function __mintAssetType(uint8 _actorIndex, bool _vaultZero, uint256 _shares, uint8 _collateralType)
        public returns (uint256 assets)
    {
        emit log_named_string("    function", "__mintAssetType");

        address actor = _chooseActor(_actorIndex);
        ISilo silo = __chooseSilo(_vaultZero);

        vm.prank(actor);
        assets = silo.mint(_shares, actor, ISilo.CollateralType(_collateralType));

        assertLe(_collateralType, 3, "we have only 3 types");
    }

    function __withdraw(uint8 _actorIndex, bool _vaultZero, uint256 _assets) public {
        emit log_named_string("    function", "__withdraw");

        address actor = _chooseActor(_actorIndex);
        ISilo silo = __chooseSilo(_vaultZero);

        vm.prank(actor);
        silo.withdraw(_assets, actor, actor);
    }

    function __maxMint_correctMax(uint8 _actorIndex, bool _vaultZero) public {
        emit log_named_string("    function", "__maxMint_correctMax");

        address actor = _chooseActor(_actorIndex);
        ISilo silo = __chooseSilo(_vaultZero);

        uint256 maxShares = silo.maxMint(address(actor));
        assertGt(maxShares, 0, "max mint is zero");

        uint256 assets = silo.previewMint(maxShares);
        assertGt(assets, 0, "expect assets not to be 0");

        emit log_named_decimal_uint("Max Shares to mint:", maxShares, 18);

        vm.prank(actor);
        assertEq(silo.mint(maxShares, actor), assets, "expect preview to be correct");
    }

    function __accrueInterest(bool _vaultZero) public {
        emit log_named_string("    function", "__accrueInterest");

        ISilo silo = __chooseSilo(_vaultZero);
        silo.accrueInterest();
    }

    function __depositAssetType(
        uint8 _actorIndex,
        bool _vaultZero,
        uint256 _amount,
        uint8 _collateralType
    )
        public returns (uint256 shares)
    {
        emit log_named_string("    function", "__depositAssetType");

        address actor = _chooseActor(_actorIndex);
        ISilo silo = __chooseSilo(_vaultZero);

        vm.prank(actor);
        shares = silo.deposit(_amount, actor, ISilo.CollateralType(_collateralType));

        assertLe(_collateralType, 3, "we have only 3 types");
    }

    function __cannotLiquidateASolventUser(uint8 _actorIndex, bool _receiveShares) public {
        emit log_named_string("    function", "__cannotLiquidateASolventUser");

        address actor = _chooseActor(_actorIndex);
        (bool isSolvent, ISilo siloWithDebt, ) = _invariant_insolventHasDebt(actor);

        assertFalse(isSolvent, "expect user to be solvent, not colvent should be ignored by echidna");

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(siloWithDebt), address(actor));
        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));

        try partialLiquidation.liquidationCall(address(siloWithDebt), debt, collateral, actor, debtToRepay, _receiveShares) {
            emit log("Solvent user liquidated!");
            assertTrue(false, "Solvent user liquidated!");
        } catch {
            // do nothing
        }
    }

    function __cannotFullyLiquidateSmallLtv(uint8 _actorIndex) public {
        emit log_named_string("    function", "__cannotFullyLiquidateSmallLtv");

        address actor = _chooseActor(_actorIndex);
        (bool isSolvent, ISilo siloWithDebt, ISilo siloWithCollateral) = _invariant_insolventHasDebt(actor);

        assertFalse(isSolvent, "expect not solvent user");

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(siloWithDebt), address(actor));
        assertFalse(isSolvent, "expect user to be not insolvent");

        uint256 ltvBefore = siloWithCollateral.getLtv(address(actor));
        uint256 lt = siloWithCollateral.getLt();

        emit log_named_decimal_uint("User LTV:", ltvBefore, 16);
        emit log_named_decimal_uint("Liq Threshold:", lt, 16);

        uint256 maxRepay = siloWithDebt.maxRepay(address(actor));
        // we assume we do not have oracle and price is 1:1
        uint256 maxPartialRepayValue = maxRepay * PartialLiquidationLib._DEBT_DUST_LEVEL / 1e18;

        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));
        partialLiquidation.liquidationCall(address(siloWithDebt), debt, collateral, actor, debtToRepay, false);

        uint256 ltvAfter = siloWithDebt.getLtv(address(actor));
        emit log_named_decimal_uint("afterLtv:", ltvAfter, 16);

        assertEq(silo0.getLtv(address(actor)), silo1.getLtv(address(actor)), "LTV must match on both silos");

        assertTrue(siloWithDebt.isSolvent(address(actor)), "expect user to be solvent (isSolvent)");

        if (debtToRepay < maxPartialRepayValue) { // if (partial)
            assertLt(ltvAfter, ltvBefore, "we expect LTV to go down after partial liquidation");
            assertGt(ltvAfter, 0, "ltvAfter > 0");
            assertLt(ltvAfter, lt, "ltvAfter < LT");
        } else {
            assertEq(ltvAfter, 0, "when not partial, user should be completely liquidated");
        }
    }

    function __cannotLiquidateUserUnderLt(uint8 _actorIndex, bool _receiveShares) public {
        emit log_named_string("    function", "__cannotLiquidateUserUnderLt");

        address actor = _chooseActor(_actorIndex);
        (bool isSolvent, ISilo siloWithDebt, ) = _invariant_insolventHasDebt(actor);

        assertTrue(isSolvent, "expect not solvent user");

        uint256 lt = siloWithDebt.getLt();
        uint256 ltv = siloWithDebt.getLtv(address(actor));

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(siloWithDebt), address(actor));

        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));

        try partialLiquidation.liquidationCall(address(siloWithDebt), debt, collateral, actor, debtToRepay, _receiveShares) {
            emit log_named_decimal_uint("User LTV:", ltv, 16);
            emit log_named_decimal_uint("Liq Threshold:", lt, 16);
            emit log("User liquidated!");
            assert(false);
        } catch {
            assertLe(ltv, lt, "ltv <= lt");

            emit log_named_string(
                "it is expected liquidationCall to throw, because user is solvent",
                isSolvent ? "YES" : "NO?!"
            );

        }
    }

    function __chooseSilo(bool _siloZero) private view returns (ISilo) {
        return _siloZero ? silo0 : silo1;
    }

    function __liquidationTokens(address _siloWithDebt) private view returns (address collateral, address debt) {
        (collateral, debt) = _siloWithDebt == address(silo0)
            ? (address(token0), address(token1))
            : (address(token1), address(token0));
    }

    function __timeDelay(uint256 _t) internal {
        vm.warp(block.timestamp + _t);
    }

    function __timeDelay(uint256 _t, uint256 _roll) internal {
        vm.warp(block.timestamp + _t);
        vm.roll(block.number + _roll);
    }

    function __prepareForLiquidationRepay(ISilo _silo, address _actor, uint256 _debtToRepay) public {
        MintableToken token = _silo == silo0 ? token0 : token1;
        token.mintOnDemand(_actor, _debtToRepay);
        vm.prank(_actor);
        token.approve(address(_silo), _debtToRepay);
    }
}
