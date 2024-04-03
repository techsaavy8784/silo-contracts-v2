// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;


import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {MaxWithdrawCommon} from "./MaxWithdrawCommon.sol";

/*
    forge test -vv --ffi --mc MaxRedeemTest
*/
contract MaxRedeemTest is MaxWithdrawCommon {
    using SiloLensLib for ISilo;

    function setUp() public {
        _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_zero
    */
    function test_maxRedeem_zero() public {
        uint256 maxRedeem = silo1.maxRedeem(borrower);
        assertEq(maxRedeem, 0, "nothing to redeem");
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_deposit_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRedeem_deposit_fuzz(
        uint112 _assets,
        uint16 _assets2
    ) public {
        vm.assume(_assets > 0);
        vm.assume(_assets2 > 0);

        _deposit(_assets, borrower);
        _deposit(_assets2, address(1)); // any

        uint256 maxRedeem = silo0.maxRedeem(borrower);
        assertEq(maxRedeem, _assets, "max withdraw == _assets/shares if no interest");

        _assertBorrowerCanNotRedeemMore(maxRedeem, TWO_ASSETS); // no borrow here, so flag does not matter
        _assertBorrowerHasNothingToRedeem();
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_whenBorrow
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRedeem_whenBorrow_1token_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        _maxRedeem_whenBorrow(_collateral, _toBorrow, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRedeem_whenBorrow_2tokens_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        _maxRedeem_whenBorrow(_collateral, _toBorrow, TWO_ASSETS);
    }

    function _maxRedeem_whenBorrow(uint128 _collateral, uint128 _toBorrow, bool _sameAsset) private {
        _createDebtOnSilo1(_collateral, _toBorrow, _sameAsset);

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;
        uint256 maxRedeem = collateralSilo.maxRedeem(borrower);

        (, address collateralShareToken, ) = collateralSilo.config().getShareTokens(address(collateralSilo));
        assertLt(maxRedeem, IShareToken(collateralShareToken).balanceOf(borrower), "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", collateralSilo.getLtv(borrower), 16);

        _assertBorrowerCanNotRedeemMore(maxRedeem, 2, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_whenInterest_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRedeem_whenInterest_1token_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        // (uint128 _collateral, uint128 _toBorrow) = (5407, 5028);
        _maxRedeem_whenInterest(_collateral, _toBorrow, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRedeem_whenInterest_2tokens_fuzz(
        uint128 _collateral,
        uint128 _toBorrow
    ) public {
        _maxRedeem_whenInterest(_collateral, _toBorrow, TWO_ASSETS);
    }

    function _maxRedeem_whenInterest(uint128 _collateral, uint128 _toBorrow, bool _sameAsset) private {
        _createDebtOnSilo1(_collateral, _toBorrow, _sameAsset);

        vm.warp(block.timestamp + 100 days);

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;

        uint256 maxRedeem = collateralSilo.maxRedeem(borrower);
        (, address collateralShareToken, ) = collateralSilo.config().getShareTokens(address(collateralSilo));
        assertLt(maxRedeem, IShareToken(collateralShareToken).balanceOf(borrower), "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", collateralSilo.getLtv(borrower), 16);

        _assertBorrowerCanNotRedeemMore(maxRedeem, _sameAsset ? 4 : 2, _sameAsset);
    }

    /*
    forge test -vv --ffi --mt test_maxRedeem_bothSilosWithInterest_
    */
    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRedeem_bothSilosWithInterest_1token_fuzz(
//        uint128 _collateral,
//        uint128 _toBorrow
    ) public {
        (uint128 _collateral, uint128 _toBorrow) = (13423, 2010);
        _maxRedeem_bothSilosWithInterest(_collateral, _toBorrow, SAME_ASSET);
    }

    /// forge-config: core-test.fuzz.runs = 1000
    function test_maxRedeem_bothSilosWithInterest_2tokens_fuzz(
//        uint128 _collateral,
//        uint128 _toBorrow
    ) public {
        (uint128 _collateral, uint128 _toBorrow) = (12655, 1740);
        _maxRedeem_bothSilosWithInterest(_collateral, _toBorrow, TWO_ASSETS);
    }

    function _maxRedeem_bothSilosWithInterest(uint128 _collateral, uint128 _toBorrow, bool _sameAsset) private {
        _createDebtOnSilo1(_collateral, _toBorrow, _sameAsset);
        _createDebtOnSilo0(_collateral, _toBorrow, _sameAsset);

        vm.warp(block.timestamp + 100 days);
        emit log("----- time travel -------");
        ISilo collateralSilo = _sameAsset ? silo1 : silo0;

        uint256 maxRedeem = collateralSilo.maxRedeem(borrower);
        (, address collateralShareToken, ) = collateralSilo.config().getShareTokens(address(collateralSilo));
        assertLt(maxRedeem, IShareToken(collateralShareToken).balanceOf(borrower), "with debt you can not withdraw all");

        emit log_named_decimal_uint("LTV", collateralSilo.getLtv(borrower), 16);

        _assertBorrowerCanNotRedeemMore(maxRedeem, 3, _sameAsset);
    }

    function _assertBorrowerHasNothingToRedeem() internal {
        (, address collateralShareToken, ) = silo0.config().getShareTokens(address(silo0));

        assertEq(silo0.maxRedeem(borrower), 0, "expect maxRedeem to be 0");
        assertEq(IShareToken(collateralShareToken).balanceOf(borrower), 0, "expect share balance to be 0");
    }

    function _assertBorrowerCanNotRedeemMore(uint256 _maxRedeem, bool _sameAsset) internal {
        _assertBorrowerCanNotRedeemMore(_maxRedeem, 1, _sameAsset);
    }

    function _assertBorrowerCanNotRedeemMore(uint256 _maxRedeem, uint256 _underestimate, bool _sameAsset) internal {
        emit log_named_uint("------- QA: _assertBorrowerCanNotRedeemMore shares", _maxRedeem);

        assertGt(_underestimate, 0, "_underestimate must be at least 1");

        ISilo collateralSilo = _sameAsset ? silo1 : silo0;

        if (_maxRedeem > 0) {
            vm.prank(borrower);
            collateralSilo.redeem(_maxRedeem, borrower, borrower);
            emit log_named_decimal_uint("LTV after aditional redeem", collateralSilo.getLtv(borrower), 16);
        }

        bool isSolvent = collateralSilo.isSolvent(borrower);

        if (!isSolvent) {
            assertEq(_maxRedeem, 0, "if user is insolvent, MAX should be always 0");
        }

        uint256 counterExample = isSolvent ? _underestimate : 1;
        emit log_named_uint("=========== [counterexample] testing counterexample for maxRedeem with", counterExample);

        vm.prank(borrower);
        vm.expectRevert();
        collateralSilo.redeem(counterExample, borrower, borrower);
    }

    function _assertMaxRedeemIsZeroAtTheEnd() internal {
        _assertMaxRedeemIsZeroAtTheEnd(0);
    }

    function _assertMaxRedeemIsZeroAtTheEnd(uint256 _underestimate) internal {
        emit log_named_uint("================= _assertMaxRedeemIsZeroAtTheEnd ================= +/-", _underestimate);

        uint256 maxRedeem = silo0.maxRedeem(borrower);

        assertLe(
            maxRedeem,
            _underestimate,
            string.concat("at this point max should return 0 +/-", string(abi.encodePacked(_underestimate)))
        );
    }
}
