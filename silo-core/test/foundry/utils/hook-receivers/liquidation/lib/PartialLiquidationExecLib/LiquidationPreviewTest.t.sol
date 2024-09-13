// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {SiloSolvencyLib} from "silo-core/contracts/lib/SiloSolvencyLib.sol";
import {PartialLiquidationExecLib} from "silo-core/contracts/utils/hook-receivers/liquidation/lib/PartialLiquidationExecLib.sol";
import {PartialLiquidationLib} from "silo-core/contracts/utils/hook-receivers/liquidation/lib/PartialLiquidationLib.sol";

import {OraclesHelper} from "../../../../../_common/OraclesHelper.sol";
import {OracleMock} from "../../../../../_mocks/OracleMock.sol";
import {PartialLiquidationExecLibImpl} from "../../../../../_common/PartialLiquidationExecLibImpl.sol";


// forge test -vv --mc LiquidationPreviewTest
contract LiquidationPreviewTest is Test, OraclesHelper {
    // this must match value from PartialLiquidationLib
    uint256 internal constant _LT_LIQUIDATION_MARGIN = 0.9e18; // 90%

    /*
    forge test -vv --mt test_liquidationPreview_noOracle_zero
    */
    function test_liquidationPreview_noOracle_zero() public view {
        SiloSolvencyLib.LtvData memory ltvData;
        PartialLiquidationLib.LiquidationPreviewParams memory params;

        (uint256 receiveCollateral, uint256 repayDebt) = PartialLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "zero collateral on empty values");
        assertEq(repayDebt, 0, "zero debt on empty values");

        ltvData.borrowerCollateralAssets = 1;
        (receiveCollateral, repayDebt) = PartialLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "zero collateral on empty debt");
        assertEq(repayDebt, 0, "zero debt on empty debt");

        ltvData.borrowerCollateralAssets = 0;
        ltvData.borrowerDebtAssets = 1;
        (receiveCollateral, repayDebt) = PartialLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "zero collateral on empty collateral");
        assertEq(repayDebt, 0, "zero debt on empty collateral");

        ltvData.borrowerCollateralAssets = 1000;
        ltvData.borrowerDebtAssets = 100;
        (receiveCollateral, repayDebt) = PartialLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "zero collateral on solvent borrower");
        assertEq(repayDebt, 0, "zero debt on solvent borrower");
    }

    /*
    forge test -vv --mt test_liquidationPreview_zero
    */
    function test_liquidationPreview_zero() public {
        SiloSolvencyLib.LtvData memory ltvData;
        ltvData.collateralOracle = ISiloOracle(collateralOracle.ADDRESS());
        ltvData.debtOracle = ISiloOracle(debtOracle.ADDRESS());

        PartialLiquidationLib.LiquidationPreviewParams memory params;
        params.collateralConfigAsset = COLLATERAL_ASSET;
        params.debtConfigAsset = DEBT_ASSET;
        params.debtToCover = 1;

        ltvData.borrowerCollateralAssets = 1;
        ltvData.borrowerDebtAssets = 1;

        uint256 collateralSum = ltvData.borrowerCollateralAssets + ltvData.borrowerProtectedAssets;
        collateralOracle.quoteMock(collateralSum, COLLATERAL_ASSET, 0);
        debtOracle.quoteMock(ltvData.borrowerDebtAssets, DEBT_ASSET, 0);

        (uint256 receiveCollateral, uint256 repayDebt) = PartialLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "zero collateral on empty values");
        assertEq(repayDebt, 0, "zero debt on empty values");
    }

    /*
    forge test -vv --mt test_liquidationPreview_revert_LiquidationTooBig
    */
    function test_liquidationPreview_revert_LiquidationTooBig() public {
        PartialLiquidationExecLibImpl impl = new PartialLiquidationExecLibImpl();

        SiloSolvencyLib.LtvData memory ltvData;
        ltvData.collateralOracle = ISiloOracle(collateralOracle.ADDRESS());
        ltvData.debtOracle = ISiloOracle(debtOracle.ADDRESS());
        ltvData.borrowerCollateralAssets = 1e18;
        ltvData.borrowerDebtAssets = 0.8e18;

        PartialLiquidationLib.LiquidationPreviewParams memory params;
        params.collateralConfigAsset = COLLATERAL_ASSET;
        params.debtConfigAsset = DEBT_ASSET;
        params.collateralLt = 0.8000e18 - 1; // must be below LTV that is present in `ltvData`

        (uint256 maxCollateralToLiquidate, uint256 maxDebtToCover) = PartialLiquidationLib.maxLiquidation(
            ltvData.borrowerCollateralAssets,
            ltvData.borrowerCollateralAssets,
            ltvData.borrowerDebtAssets,
            ltvData.borrowerDebtAssets,
            params.collateralLt,
            params.liquidationFee
        );

        emit log_named_decimal_uint("maxDebtToCover", maxDebtToCover, 18);

        params.debtToCover = maxDebtToCover;
        // price is 1:1
        uint256 collateralSum = ltvData.borrowerCollateralAssets + ltvData.borrowerProtectedAssets;
        collateralOracle.quoteMock(collateralSum, COLLATERAL_ASSET, collateralSum);
        debtOracle.quoteMock(ltvData.borrowerDebtAssets, DEBT_ASSET, ltvData.borrowerDebtAssets);

        // does not revert - counter example first
        (uint256 receiveCollateralAssets, uint256 repayDebtAssets) = impl.liquidationPreview(ltvData, params);
        // -2 because we underestimating max value
        assertEq(receiveCollateralAssets - 2, maxCollateralToLiquidate, "expect same collateral #1");
        assertEq(receiveCollateralAssets, maxDebtToCover, "same collateral, because price is 1:1 and no fee #1");
        assertEq(repayDebtAssets, maxDebtToCover, "repayDebtAssets match #1");

        // more debt should cause revert because of _LT_LIQUIDATION_MARGIN_IN_BP
        params.debtToCover += 1;

        // does not revert for self liquidation - counter example first
        params.selfLiquidation = true;
        (receiveCollateralAssets, repayDebtAssets) = impl.liquidationPreview(ltvData, params);
        assertEq(receiveCollateralAssets, maxDebtToCover + 1, "receiveCollateralAssets #2");
        assertEq(repayDebtAssets, maxDebtToCover + 1, "repayDebtAssets #2");

        params.selfLiquidation = false;
        (receiveCollateralAssets, repayDebtAssets) = impl.liquidationPreview(ltvData, params);
        assertEq(receiveCollateralAssets, maxDebtToCover, "receiveCollateralAssets #3 - cap to max");
        assertEq(repayDebtAssets, maxDebtToCover, "repayDebtAssets #3 - cap to max");
    }

    /*
    forge test -vv --mt test_liquidationPreview_selfLiquidation_whenSolvent
    */
    function test_liquidationPreview_selfLiquidation_whenSolvent() public {
        SiloSolvencyLib.LtvData memory ltvData;
        ltvData.collateralOracle = ISiloOracle(collateralOracle.ADDRESS());
        ltvData.debtOracle = ISiloOracle(debtOracle.ADDRESS());
        ltvData.borrowerCollateralAssets = 1e18;
        ltvData.borrowerDebtAssets = 1e18;

        PartialLiquidationLib.LiquidationPreviewParams memory params;
        params.collateralConfigAsset = COLLATERAL_ASSET;
        params.debtConfigAsset = DEBT_ASSET;
        params.collateralLt = 0.8e18;
        params.debtToCover = 2;

        // ltv 50% - user solvent
        collateralOracle.quoteMock(ltvData.borrowerCollateralAssets + ltvData.borrowerProtectedAssets, COLLATERAL_ASSET, 1e18);
        debtOracle.quoteMock(ltvData.borrowerDebtAssets, DEBT_ASSET, 0.5e18);

        (uint256 receiveCollateral, uint256 repayDebt) = PartialLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 0, "no collateral - user is solvent");
        assertEq(repayDebt, 0, "no debt - user is solvent");

        params.selfLiquidation = true;
        (receiveCollateral, repayDebt) = PartialLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 1, "some collateral - self-liquidation");
        assertEq(repayDebt, 2, "some debt - self-liquidation");
    }

    /*
    forge test -vv --mt test_liquidationPreview_whenNotSolvent
    */
    function test_liquidationPreview_whenNotSolvent() public view {
        SiloSolvencyLib.LtvData memory ltvData;
        ltvData.borrowerCollateralAssets = 1e18;
        ltvData.borrowerDebtAssets = 2e18; // 200% LTV

        PartialLiquidationLib.LiquidationPreviewParams memory params;
        params.collateralConfigAsset = COLLATERAL_ASSET;
        params.debtConfigAsset = DEBT_ASSET;
        params.collateralLt = 0.8e18;
        params.debtToCover = 2;

        // ltv 200% - user NOT solvent
        // no oracle calls

        (uint256 receiveCollateral, uint256 repayDebt) = PartialLiquidationExecLib.liquidationPreview(ltvData, params);
        assertEq(receiveCollateral, 2, "receiveCollateral");
        assertEq(repayDebt, 2, "repayDebt");
    }
}
