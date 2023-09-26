// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract CalculateExactLiquidationAmountsTestData {
    struct Input {
        uint256 debtToCover;
        uint256 totalBorrowerDebtValue;
        uint256 totalBorrowerDebtAssets;
        uint256 totalBorrowerCollateralValue;
        uint256 totalBorrowerCollateralAssets;
        uint256 liquidationFee;
    }

    struct Output {
        uint256 collateralAssetsToLiquidate;
        uint256 debtAssetsToRepay;
        uint256 ltvAfterLiquidation;
    }

    struct CELAData {
        Input input;
        Output output;
    }

    function readDataFromJson() external pure returns (CELAData[] memory data) {
        data = new CELAData[](11);
        uint256 i;

        data[i++] = CELAData({ // #0
            input: Input({
                debtToCover: 0,
                totalBorrowerDebtValue: 1,
                totalBorrowerDebtAssets: 1,
                totalBorrowerCollateralValue: 1,
                totalBorrowerCollateralAssets: 1,
                liquidationFee: 0
            }),
            output: Output({
                collateralAssetsToLiquidate: 0,
                debtAssetsToRepay: 0,
                ltvAfterLiquidation: 1e4
            })
        });

        data[i++] = CELAData({ // #1
            input: Input({
                debtToCover: 0,
                totalBorrowerDebtValue: 1,
                totalBorrowerDebtAssets: 1,
                totalBorrowerCollateralValue: 1,
                totalBorrowerCollateralAssets: 1,
                liquidationFee: 0
            }),
            output: Output({
                collateralAssetsToLiquidate: 0,
                debtAssetsToRepay: 0,
                ltvAfterLiquidation: 1e4
            })
        });

        data[i++] = CELAData({ // #2
            input: Input({
                debtToCover: 0,
                totalBorrowerDebtValue: 1,
                totalBorrowerDebtAssets: 1,
                totalBorrowerCollateralValue: 1,
                totalBorrowerCollateralAssets: 1,
                liquidationFee: 1e3
            }),
            output: Output({
                collateralAssetsToLiquidate: 0,
                debtAssetsToRepay: 0,
                ltvAfterLiquidation: 1e4
            })
        });

        data[i++] = CELAData({ // #3
            input: Input({
                debtToCover: 0,
                totalBorrowerDebtValue: 1e18,
                totalBorrowerDebtAssets: 1e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 100e18,
                liquidationFee: 1e3
            }),
            output: Output({
                collateralAssetsToLiquidate: 0,
                debtAssetsToRepay: 0,
                ltvAfterLiquidation: 100
            })
        });

        data[i++] = CELAData({ // #4
            input: Input({
                debtToCover: 1,
                totalBorrowerDebtValue: 1e18,
                totalBorrowerDebtAssets: 1e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 100e18,
                liquidationFee: 1e3
            }),
            output: Output({
                collateralAssetsToLiquidate: 1,
                debtAssetsToRepay: 1,
                ltvAfterLiquidation: 99
            })
        });

        data[i++] = CELAData({ // #5
            input: Input({
                debtToCover: 10,
                totalBorrowerDebtValue: 1e18,
                totalBorrowerDebtAssets: 1e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 100e18,
                liquidationFee: 1e3
            }),
            output: Output({
                collateralAssetsToLiquidate: 11, // smallest fee
                debtAssetsToRepay: 10,
                ltvAfterLiquidation: 99
            })
        });

        data[i++] = CELAData({ // #6
            input: Input({
                debtToCover: 0.5e18, // the value is 40e18 + fee => 44e18 in value
                totalBorrowerDebtValue: 80e18,
                totalBorrowerDebtAssets: 1e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 10e18,
                liquidationFee: 1e3
            }),
            output: Output({
                collateralAssetsToLiquidate: 44e18 / 10,
                debtAssetsToRepay: 0.5e18,
                ltvAfterLiquidation: 7142
            })
        });

        // this is just before full liquidation because of "dust"
        data[i++] = CELAData({ // #7
            input: Input({
                debtToCover: 0.90e18, // the value is 72e18 + fee => 79.2e18 in value
                totalBorrowerDebtValue: 80e18,
                totalBorrowerDebtAssets: 1e18,
                totalBorrowerCollateralValue: 9_000e18,
                totalBorrowerCollateralAssets: 10e18,
                liquidationFee: 1e3
            }),
            output: Output({
                collateralAssetsToLiquidate: 79.2e18 / 900,
                debtAssetsToRepay: 0.90e18,
                ltvAfterLiquidation: 8 // ~0.0007847
            })
        });

        // this will do full liquidation because of dust
        // input values are made up and looks like we have huge collateral
        // but the math in this method does not care about ltv and logic, it just calculates
        data[i++] = CELAData({ // #8
            input: Input({
                debtToCover: 0.91e18, // the value is 72.8e18, but this is over "dust" margin, so it will be full
                totalBorrowerDebtValue: 80e18,
                totalBorrowerDebtAssets: 1e18, // 1debt token == 80 in value
                totalBorrowerCollateralValue: 9_000e18,
                totalBorrowerCollateralAssets: 10e18, // 1token == 900 in value
                liquidationFee: 1e3
            }),
            output: Output({
                collateralAssetsToLiquidate: uint256(80e18 + 80e18 * 1e3 / 1e4) / 900,
                debtAssetsToRepay: 1e18,
                ltvAfterLiquidation: 0
            })
        });

        // if we expect ltv to be 0, we need full liquidation
        data[i++] = CELAData({ // #9
            input: Input({
                debtToCover: 160e18,
                totalBorrowerDebtValue: 80e18,
                totalBorrowerDebtAssets: 160e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 300e18,
                liquidationFee: 500
            }),
            output: Output({
                collateralAssetsToLiquidate: (80e18 + 80e18 * 500 / 1e4) * 3, // 252...
                debtAssetsToRepay: 160e18,
                ltvAfterLiquidation: 0
            })
        });

        data[i++] = CELAData({ // #10
            input: Input({
                debtToCover: 10e18,
                totalBorrowerDebtValue: 180e18,
                totalBorrowerDebtAssets: 180e18,
                totalBorrowerCollateralValue: 100e18,
                totalBorrowerCollateralAssets: 100e18,
                liquidationFee: 1000
            }),
            output: Output({
                collateralAssetsToLiquidate: (10e18 + 10e18 * 1000 / 1e4),
                debtAssetsToRepay: 10e18,
                ltvAfterLiquidation: 1_9101
            })
        });
    }
}
