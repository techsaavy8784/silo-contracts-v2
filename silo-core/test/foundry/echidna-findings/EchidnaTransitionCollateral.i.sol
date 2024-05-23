// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Strings} from "openzeppelin5/utils/Strings.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {EchidnaMiddleman} from "./EchidnaMiddleman.sol";

/*
    forge test -vv --ffi --mc EchidnaMaxWithdrawTest
*/
contract EchidnaTransitionCollateralTest is EchidnaMiddleman {
    /*
transitionCollateral_doesNotResultInMoreShares(uint8,bool,uint256,uint8): failed!💥
  Call sequence, shrinking 163/500:
    previewDeposit_doesNotReturnMoreThanDeposit(0,1957414557617622995)
    deposit(13,false,3441335788914495287800899557082375368528531556117096880894049040840472934976)
    borrowShares(42,false,2)
    maxRedeem_correctMax(1)
    cannotLiquidateASolventUser(0,false) Time delay: 150273 seconds Block delay: 4354
    depositAssetType(0,false,115419216813914548806106100049,0) Time delay: 233520 seconds Block delay: 19164
    maxRedeem_correctMax(0) Time delay: 322320 seconds Block delay: 49849
    transitionCollateral_doesNotResultInMoreShares(0,false,91151606349439528474,0)


    forge test -vv --ffi --mt test_echidna_scenario_transitionCollateral_1

    this test case covers the bug we had in maxBorrow
    */
    function test_echidna_scenario_transitionCollateral_1() public {
        __previewDeposit_doesNotReturnMoreThanDeposit(0,1957414557617622995);
        __deposit(13,false,3441335788914495287800899557082375368528531556117096880894049040840472934976);
        __borrowShares(42,false,2);
        __maxRedeem_correctMax(1);

        __timeDelay(150273);
        // __cannotLiquidateASolventUser(0,false); //  Time delay: 150273 seconds Block delay: 4354

        __timeDelay(233520);
        __depositAssetType(0,false,115419216813914548806106100049,0); // Time delay: 233520 seconds Block delay: 19164

        __timeDelay(322320);
        __maxRedeem_correctMax(0); // Time delay: 322320 seconds Block delay: 49849

        __transitionCollateral_doesNotResultInMoreShares(0,false,91151606349439528474,0);
    }
}
