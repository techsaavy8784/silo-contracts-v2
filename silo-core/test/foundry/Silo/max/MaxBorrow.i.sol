// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxBorrowTest
*/
contract MaxBorrowTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;
    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_noCollateral
    */
    function test_maxBorrow_noCollateral() public {
        uint256 maxBorrow = silo1.maxBorrow(borrower);
        assertEq(maxBorrow, 0, "no collateral - no borrow");

        _assertWeCanNotBorrowAboveMax(0);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_withCollateral_fuzz
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxBorrow_withCollateral_fuzz(
        uint128 _collateral,
        uint128 _liquidity
    ) public {
        vm.assume(_liquidity > 0);
        vm.assume(_collateral > 0);

        _depositForBorrow(_liquidity, depositor);
        _deposit(_collateral, borrower);

        uint256 maxBorrow = silo1.maxBorrow(borrower);
        emit log_named_decimal_uint("maxBorrow", maxBorrow, 18);

        _assertWeCanNotBorrowAboveMax(maxBorrow, 2);
        _assertMaxBorrowIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_collateralButNoLiquidity
    */
    /// forge-config: core.fuzz.runs = 100
    function test_maxBorrow_collateralButNoLiquidity_fuzz(uint128 _collateral) public {
        vm.assume(_collateral > 0);

        _deposit(_collateral, borrower);

        _assertMaxBorrowIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_withDebt
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxBorrow_withDebt_fuzz(uint128 _collateral, uint128 _liquidity) public {
        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _deposit(_collateral, borrower);
        _depositForBorrow(_liquidity, depositor);

        uint256 maxBorrow = silo1.maxBorrow(borrower);

        uint256 firstBorrow = maxBorrow / 3;
        vm.assume(firstBorrow > 0);
        _borrow(firstBorrow, borrower);

        // now we have debt

        maxBorrow = silo1.maxBorrow(borrower);
        _assertWeCanNotBorrowAboveMax(maxBorrow, 2);

        _assertMaxBorrowIsZeroAtTheEnd();
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_withInterest
    */
    /// forge-config: core.fuzz.runs = 1000
    function test_maxBorrow_withInterest_fuzz(
        uint128 _collateral,
        uint128 _liquidity
    ) public {
        // (uint128 _collateral, uint128 _liquidity) = (21257, 22568);

        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _deposit(_collateral, borrower);
        _depositForBorrow(_liquidity, depositor);

        uint256 maxBorrow = silo1.maxBorrow(borrower);

        uint256 firstBorrow = maxBorrow / 3;
        emit log_named_uint("firstBorrow", firstBorrow);
        vm.assume(firstBorrow > 0);
        _borrow(firstBorrow, borrower);

        // now we have debt
        vm.warp(block.timestamp + 100 days);

        maxBorrow = silo1.maxBorrow(borrower);
        emit log_named_uint("maxBorrow", maxBorrow);

        _assertWeCanNotBorrowAboveMax(maxBorrow, 4);

        _assertMaxBorrowIsZeroAtTheEnd(1);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_repayWithInterest_fuzz
    */
    /// forge-config: core.fuzz.runs = 5000
    function test_maxBorrow_repayWithInterest_fuzz(
        uint64 _collateral,
        uint128 _liquidity
    ) public {
        // (uint64 _collateral, uint128 _liquidity) = (14342, 20038);
        vm.assume(_collateral > 0);
        vm.assume(_liquidity > 0);

        _deposit(_collateral, borrower);
        _depositForBorrow(_liquidity, depositor);

        uint256 maxBorrow = silo1.maxBorrow(borrower);

        uint256 firstBorrow = maxBorrow / 3;
        emit log_named_uint("firstBorrow", firstBorrow);
        vm.assume(firstBorrow > 0);
        _borrow(firstBorrow, borrower);

        // now we have debt
        vm.warp(block.timestamp + 100 days);
        emit log("----- time travel -----");

        (,, address debtShareToken) = silo1.config().getShareTokens(address(silo1));

        token1.setOnDemand(true);
        uint256 debt = IShareToken(debtShareToken).balanceOf(borrower);
        emit log_named_decimal_uint("user shares", debt, 18);
        uint256 debtToRepay = debt * 9 / 10 == 0 ? 1 : debt * 9 / 10;
        emit log_named_decimal_uint("debtToRepay", debtToRepay, 18);

        _repayShares(1, debtToRepay, borrower);
        token1.setOnDemand(false);

        // maybe we have some debt left, maybe not

        maxBorrow = silo1.maxBorrow(borrower);
        assertGt(maxBorrow, 0, "we can borrow again after repay");

        _assertWeCanNotBorrowAboveMax(maxBorrow, 4);
        _assertMaxBorrowIsZeroAtTheEnd(1);
    }

    /*
    forge test -vv --ffi --mt test_maxBorrow_maxOut
    */
    function test_maxBorrow_maxOut() public {
        address user0 = makeAddr("user0");
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        emit log("User 1 deposits 54901887191424375183106916902 assets into Silo 2");
        _depositForBorrow(54901887191424375183106916902, user1);

        emit log("User 0 deposits 37778931862957161709569 assets into Silo 1");
        _deposit(37778931862957161709569, user0);

        emit log("User 2 mints 57553484963063775982514231325194206610732636 shares from Silo 2");

        token1.setOnDemand(true);
        _mintForBorrow(1, 57553484963063775982514231325194206610732636, user2);
        token1.setOnDemand(false);

        emit log_named_uint("User 1 max borrow on silo1", silo0.maxBorrow(user1));
        emit log_named_uint("User 1 max borrow on silo2", silo1.maxBorrow(user1));

        emit log("User 1 borrows the maximum returned from maxBorrow from Silo 1");
        vm.startPrank(user1);
        silo0.borrow(silo0.maxBorrow(user1), user1, user1);
        vm.stopPrank();

        vm.warp(block.timestamp + 41);

        emit log("Timestamp is increased by 41 seconds");

        emit log("User 0 deposits 1157...127042 assets into Silo 1");
        _deposit(115792089237316195417293883273301227089434195242432897623355228563449095127042, user0);

        uint256 liquidity = silo0.getLiquidity();
        emit log_named_uint("liquidity on the fly", liquidity);
        silo0.accrueInterest();
        assertEq(liquidity, silo0.getLiquidity());

        uint256 maxBorrow = silo0.maxBorrow(user2);
        emit log_named_uint("user2 maxBorrow", maxBorrow);

        emit log("User 2 attempts to borrow maxBorrow assets, it should NOT fail with AboveMaxLtv()");
        vm.prank(user2);
        silo0.borrow(maxBorrow, user2, user2); // expect to pass
    }

    function _assertWeCanNotBorrowAboveMax(uint256 _maxBorrow) internal {
        _assertWeCanNotBorrowAboveMax(_maxBorrow, 1);
    }

    /// @param _precision is needed because we count for precision error and we allow for 1 wei diff
    function _assertWeCanNotBorrowAboveMax(uint256 _maxBorrow, uint256 _precision) internal {
        emit log_named_uint("------- QA: _assertWeCanNotBorrowAboveMax +/-", _precision);

        uint256 toBorrow = _maxBorrow + _precision;

        uint256 liquidity = silo1.getLiquidity();

        emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax] liquidity", liquidity, 18);
        emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax]  toBorrow", toBorrow, 18);

        vm.prank(borrower);
        try silo1.borrow(toBorrow, borrower, borrower) returns (uint256) {
            revert("we expect tx to be reverted for _maxBorrow + _precision!");
        } catch (bytes memory data) {
            bytes4 errorType = bytes4(data);

            bytes4 error1 = bytes4(keccak256(abi.encodePacked("NotEnoughLiquidity()")));
            bytes4 error2 = bytes4(keccak256(abi.encodePacked("AboveMaxLtv()")));

            if (errorType != error1 && errorType != error2) {
                revert("we need to revert with NotEnoughLiquidity or AboveMaxLtv");
            }
        }

        if (_maxBorrow > 0) {
            emit log_named_decimal_uint("[_assertWeCanNotBorrowAboveMax] _maxBorrow > 0 YES, borrowing max", _maxBorrow, 18);
            vm.prank(borrower);
            silo1.borrow(_maxBorrow, borrower, borrower);
        }
    }

    function _assertMaxBorrowIsZeroAtTheEnd() internal {
        _assertMaxBorrowIsZeroAtTheEnd(0);
    }

    function _assertMaxBorrowIsZeroAtTheEnd(uint256 _underestimatedBy) internal {
        emit log_named_uint("================ _assertMaxBorrowIsZeroAtTheEnd ================ +/-", _underestimatedBy);

        uint256 maxBorrow = silo1.maxBorrow(borrower);

        assertLe(
            maxBorrow,
            _underestimatedBy,
            string.concat("at this point max should return 0 +/-", string(abi.encodePacked(_underestimatedBy)))
        );
    }
}
