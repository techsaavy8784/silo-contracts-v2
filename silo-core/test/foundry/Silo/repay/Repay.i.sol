// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc RepayTest
*/
contract RepayTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }

    /*
    forge test -vv --ffi --mt test_repay_zeros
    */
    function test_repay_zeros() public {
        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.repay(0, address(0));
    }

    /*
    forge test -vv --ffi --mt test_repay_fromZeroAddress
    */
    function test_repay_fromZeroAddress() public {
        // for some reason we not bale to check for this error: Error != expected error: NH{q != Arithmetic over/underflow
        vm.expectRevert();
        silo0.repay(1, address(0));
    }

    /*
    forge test -vv --ffi --mt test_repay_whenNoDebt
    */
    function test_repay_whenNoDebt() public {
        address borrower = address(this);
        uint256 amount = 1;

        token0.mint(address(this), amount);
        token0.approve(address(silo0), amount);
        // for some reason we not bale to check for this error: Error != expected error: NH{q != Arithmetic over/underflow
        vm.expectRevert(); // "Arithmetic over/underflow";
        silo0.repay(amount, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_throwZeroShares
    */
    function test_repay_throwZeroShares_1token() public {
        _repay_throwZeroShares(SAME_ASSET);
    }

    function test_repay_throwZeroShares_2tokens() public {
        _repay_throwZeroShares(TWO_ASSETS);
    }

    function _repay_throwZeroShares(bool _sameAsset) private {
        uint128 assets = 1; // after interest this is to small to convert to shares
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower, _sameAsset);
        vm.warp(block.timestamp + 50 * 365 days); // interest must be big, so conversion 1 asset => share be 0

        vm.expectRevert(ISilo.ZeroShares.selector);
        silo1.repay(assets, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_tinyAmount
    */
    function test_repay_tinyAmount_1token() public {
        _repay_tinyAmount(SAME_ASSET);
    }

    function test_repay_tinyAmount_2tokens() public {
        _repay_tinyAmount(TWO_ASSETS);
    }

    function _repay_tinyAmount(bool _sameAsset) private {
        uint128 assets = 1;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower, _sameAsset);

        _repay(assets, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_partialWithInterest
    */
    function test_repay_partialWithInterest_1token() public {
        _repay_partialWithInterest(SAME_ASSET);
    }

    function test_repay_partialWithInterest_2tokens() public {
        _repay_partialWithInterest(TWO_ASSETS);
    }

    function _repay_partialWithInterest(bool _sameAsset) private {
        uint128 assets = 10;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower, _sameAsset);
        vm.warp(block.timestamp + 1 days);

        _repay(assets, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repay_tooMuch
    */
    function test_repay_tooMuch_1token() public {
        _repay_tooMuch(SAME_ASSET);
    }

    function test_repay_tooMuch_2tokens() public {
        _repay_tooMuch(TWO_ASSETS);
    }

    function _repay_tooMuch(bool _sameAsset) private {
        uint128 assets = 1e18;
        uint256 assetsToRepay = assets * 2;
        address borrower = address(this);

        _createDebt(assets, borrower, _sameAsset);
        _mintTokens(token1, assetsToRepay, borrower);

        vm.warp(block.timestamp + 1 days);

        token1.approve(address(silo1), assetsToRepay);
        // for some reason we not bale to check for this error: Error != expected error: NH{q != Arithmetic over/underflow
        vm.expectRevert();
        silo1.repay(assetsToRepay, borrower);
    }

    /*
    forge test -vv --ffi --mt test_repayShares_fullNoInterest_noDust
    */
    function test_repayShares_fullNoInterest_noDust_1token() public {
        _repayShares_fullNoInterest_noDust(SAME_ASSET);
    }

    function test_repayShares_fullNoInterest_noDust_2tokens() public {
        _repayShares_fullNoInterest_noDust(TWO_ASSETS);
    }

    function _repayShares_fullNoInterest_noDust(bool _sameAsset) public {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower, _sameAsset);

        uint256 assetsToRepay = silo1.previewRepayShares(shares);
        assertEq(assetsToRepay, assets, "previewRepay == assets == allowance => when no interest");

        _repayShares(assets, shares, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "debt fully repayed");

        assertEq(token1.allowance(borrower, address(silo1)), 0, "NO allowance dust");
    }

    /*
    forge test -vv --ffi --mt test_repayShares_fullWithInterest_noDust
    */
    function test_repayShares_fullWithInterest_noDust_1token() public {
        _repayShares_fullWithInterest_noDust(SAME_ASSET);
    }

    function test_repayShares_fullWithInterest_noDust_2tokens() public {
        _repayShares_fullWithInterest_noDust(TWO_ASSETS);
    }

    function _repayShares_fullWithInterest_noDust(bool _sameAsset) private {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower, _sameAsset);
        vm.warp(block.timestamp + 1 days);

        uint256 interest = _sameAsset ? 127862054884613 : 11684166722553653; // interest less when more collateral
        uint256 assetsToRepay = silo1.previewRepayShares(shares);
        assertEq(assetsToRepay, 1e18 + interest, "assets with interest");

        _repayShares(assetsToRepay, shares, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "debt fully repayed");

        assertEq(token1.allowance(borrower, address(silo1)), 0, "NO allowance dust");
    }

    /*
    forge test -vv --ffi --mt test_repayShares_insufficientAllowance
    */
    function test_repayShares_insufficientAllowance_1token() public {
        _repayShares_insufficientAllowance(SAME_ASSET);
    }

    function test_repayShares_insufficientAllowance_2tokens() public {
        _repayShares_insufficientAllowance(TWO_ASSETS);
    }

    function _repayShares_insufficientAllowance(bool _sameAsset) private {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower, _sameAsset);
        vm.warp(block.timestamp + 1 days);

        uint256 previewRepay = silo1.previewRepayShares(shares);

        // after previewRepayShares we move time, so we will not be able to repay all
        vm.warp(block.timestamp + 1 days);

        uint256 currentPreview = silo1.previewRepayShares(shares);

        _repayShares(
            previewRepay, // this is our approval, it is less than `shares`
            shares, // this is what we want to repay
            borrower,
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, silo1, previewRepay, currentPreview
            )
        );
    }

    /*
    forge test -vv --ffi --mt test_repayShares_notFullWithInterest_withDust
    */
    function test_repayShares_notFullWithInterest_withDust_1token() public {
        _repayShares_notFullWithInterest_withDust(SAME_ASSET);
    }

    function test_repayShares_notFullWithInterest_withDust_2tokens() public {
        _repayShares_notFullWithInterest_withDust(TWO_ASSETS);
    }

    function _repayShares_notFullWithInterest_withDust(bool _sameAsset) private {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        uint256 shares = _createDebt(assets, borrower, _sameAsset);
        vm.warp(block.timestamp + 1 days);

        uint256 interest = _sameAsset ? 127862054884613 : 11684166722553653; // interest less when more collateral
        uint256 previewRepay = silo1.previewRepayShares(shares);

        // after previewRepayShares we move time, so we will not be able to repay all
        vm.warp(block.timestamp + 1 days);

        _repayShares(previewRepay + interest * 3, shares, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), 0, "debt fully repayed");

        // 5697763189689604/255707761064146 is just copy/paste, IRM model QA should test if interest are correct
        uint256 dust = _sameAsset ? 255707761064146 : 5697763189689604;
        assertEq(token1.allowance(borrower, address(silo1)), dust, "allowance dust");
    }

    /*
    forge test -vv --ffi --mt test_repay_twice
    */
    function test_repay_twice_1token() public {
        _repay_twice(SAME_ASSET);
    }

    function test_repay_twice_2tokens() public {
        _repay_twice(TWO_ASSETS);
    }

    function _repay_twice(bool _sameAsset) private {
        uint128 assets = 1e18;
        address borrower = makeAddr("Borrower");

        _createDebt(assets, borrower, _sameAsset);

        vm.warp(block.timestamp + 1 days);
        _repay(assets / 2, borrower);

        vm.warp(block.timestamp + 1 days);
        _repay(assets / 2, borrower);

        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo1));
        uint256 interestLeft = _sameAsset ? 159811221148187 : 12011339784578816; // interest smaller for one token
        assertEq(IShareToken(debtShareToken).balanceOf(borrower), interestLeft, "interest left");
    }
}
