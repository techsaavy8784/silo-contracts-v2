// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IMethodReentrancyTest} from "../interfaces/IMethodReentrancyTest.sol";
import {IMethodsRegistry} from "../interfaces/IMethodsRegistry.sol";

import {AccrueInterestReentrancyTest} from "../methods/silo/AccrueInterestReentrancyTest.sol";
import {AccrueInterestForConfigReentrancyTest} from "../methods/silo/AccrueInterestForConfigReentrancyTest.sol";
import {AllowanceReentrancyTest} from "../methods/silo/AllowanceReentrancyTest.sol";
import {ApproveReentrancyTest} from "../methods/silo/ApproveReentrancyTest.sol";
import {AssetReentrancyTest} from "../methods/silo/AssetReentrancyTest.sol";
import {BalanceOfReentrancyTest} from "../methods/silo/BalanceOfReentrancyTest.sol";
import {BorrowReentrancyTest} from "../methods/silo/BorrowReentrancyTest.sol";
import {BorrowSameAssetReentrancyTest} from "../methods/silo/BorrowSameAssetReentrancyTest.sol";
import {BorrowSharesReentrancyTest} from "../methods/silo/BorrowSharesReentrancyTest.sol";
import {CallOnBehalfOfSiloReentrancyTest} from "../methods/silo/CallOnBehalfOfSiloReentrancyTest.sol";
import {ConfigReentrancyTest} from "../methods/silo/ConfigReentrancyTest.sol";
import {ConvertToAssetsReentrancyTest} from "../methods/silo/ConvertToAssetsReentrancyTest.sol";
import {ConvertToAssetsWithTypeReentrancyTest} from "../methods/silo/ConvertToAssetsWithTypeReentrancyTest.sol";
import {ConvertToSharesReentrancyTest} from "../methods/silo/ConvertToSharesReentrancyTest.sol";
import {ConvertToSharesWithTypeReentrancyTest} from "../methods/silo/ConvertToSharesWithTypeReentrancyTest.sol";
import {DecimalsReentrancyTest} from "../methods/silo/DecimalsReentrancyTest.sol";
import {DepositReentrancyTest} from "../methods/silo/DepositReentrancyTest.sol";
import {DepositWithTypeReentrancyTest} from "../methods/silo/DepositWithTypeReentrancyTest.sol";
import {FactoryReentrancyTest} from "../methods/silo/FactoryReentrancyTest.sol";
import {FlashFeeReentrancyTest} from "../methods/silo/FlashFeeReentrancyTest.sol";
import {FlashLoanReentrancyTest} from "../methods/silo/FlashLoanReentrancyTest.sol";
import {GetCollateralAndDebtAssetsReentrancyTest} from "../methods/silo/GetCollateralAndDebtAssetsReentrancyTest.sol";
import {GetCollateralAndProtectedAssetsReentrancyTest}
    from "../methods/silo/GetCollateralAndProtectedAssetsReentrancyTest.sol";
import {GetCollateralAssetsReentrancyTest} from "../methods/silo/GetCollateralAssetsReentrancyTest.sol";
import {GetDebtAssetsReentrancyTest} from "../methods/silo/GetDebtAssetsReentrancyTest.sol";
import {GetLiquidityReentrancyTest} from "../methods/silo/GetLiquidityReentrancyTest.sol";
import {InitializeReentrancyTest} from "../methods/silo/InitializeReentrancyTest.sol";
import {IsSolventReentrancyTest} from "../methods/silo/IsSolventReentrancyTest.sol";
import {LeverageSameAssetReentrancyTest} from "../methods/silo/LeverageSameAssetReentrancyTest.sol";
import {MaxBorrowReentrancyTest} from "../methods/silo/MaxBorrowReentrancyTest.sol";
import {MaxBorrowSameAssetReentrancyTest} from "../methods/silo/MaxBorrowSameAssetReentrancyTest.sol";
import {MaxBorrowSharesReentrancyTest} from "../methods/silo/MaxBorrowSharesReentrancyTest.sol";
import {MaxDepositReentrancyTest} from "../methods/silo/MaxDepositReentrancyTest.sol";
import {MaxDepositWithTypeReentrancyTest} from "../methods/silo/MaxDepositWithTypeReentrancyTest.sol";
import {MaxFlashLoanReentrancyTest} from "../methods/silo/MaxFlashLoanReentrancyTest.sol";
import {MaxMintReentrancyTest} from "../methods/silo/MaxMintReentrancyTest.sol";
import {MaxMintWithTypeReentrancyTest} from "../methods/silo/MaxMintWithTypeReentrancyTest.sol";
import {MaxRedeemReentrancyTest} from "../methods/silo/MaxRedeemReentrancyTest.sol";
import {MaxRedeemWithTypeReentrancyTest} from "../methods/silo/MaxRedeemWithTypeReentrancyTest.sol";
import {MaxRepayReentrancyTest} from "../methods/silo/MaxRepayReentrancyTest.sol";
import {MaxRepaySharesReentrancyTest} from "../methods/silo/MaxRepaySharesReentrancyTest.sol";
import {MaxWithdrawReentrancyTest} from "../methods/silo/MaxWithdrawReentrancyTest.sol";
import {MaxWithdrawWithTypeReentrancyTest} from "../methods/silo/MaxWithdrawWithTypeReentrancyTest.sol";
import {MintReentrancyTest} from "../methods/silo/MintReentrancyTest.sol";
import {MintWithTypeReentrancyTest} from "../methods/silo/MintWithTypeReentrancyTest.sol";
import {NameReentrancyTest} from "../methods/silo/NameReentrancyTest.sol";
import {PreviewBorrowReentrancyTest} from "../methods/silo/PreviewBorrowReentrancyTest.sol";
import {PreviewBorrowSharesReentrancyTest} from "../methods/silo/PreviewBorrowSharesReentrancyTest.sol";
import {PreviewDepositReentrancyTest} from "../methods/silo/PreviewDepositReentrancyTest.sol";
import {PreviewDepositWithTypeReentrancyTest} from "../methods/silo/PreviewDepositWithTypeReentrancyTest.sol";
import {PreviewMintReentrancyTest} from "../methods/silo/PreviewMintReentrancyTest.sol";
import {PreviewMintWithTypeReentrancyTest} from "../methods/silo/PreviewMintWithTypeReentrancyTest.sol";
import {PreviewRedeemReentrancyTest} from "../methods/silo/PreviewRedeemReentrancyTest.sol";
import {PreviewRedeemWithTypeReentrancyTest} from "../methods/silo/PreviewRedeemWithTypeReentrancyTest.sol";
import {PreviewRepayReentrancyTest} from "../methods/silo/PreviewRepayReentrancyTest.sol";
import {PreviewRepaySharesReentrancyTest} from "../methods/silo/PreviewRepaySharesReentrancyTest.sol";
import {PreviewWithdrawReentrancyTest} from "../methods/silo/PreviewWithdrawReentrancyTest.sol";
import {PreviewWithdrawWithTypeReentrancyTest} from "../methods/silo/PreviewWithdrawWithTypeReentrancyTest.sol";
import {RedeemReentrancyTest} from "../methods/silo/RedeemReentrancyTest.sol";
import {RedeemWithTypeReentrancyTest} from "../methods/silo/RedeemWithTypeReentrancyTest.sol";
import {RepayReentrancyTest} from "../methods/silo/RepayReentrancyTest.sol";
import {RepaySharesReentrancyTest} from "../methods/silo/RepaySharesReentrancyTest.sol";
import {SharedStorageReentrancyTest} from "../methods/silo/SharedStorageReentrancyTest.sol";
import {SiloDataStorageReentrancyTest} from "../methods/silo/SiloDataStorageReentrancyTest.sol";
import {SwitchCollateralToThisSiloReentrancyTest} from "../methods/silo/SwitchCollateralToThisSiloReentrancyTest.sol";
import {SymbolReentrancyTest} from "../methods/silo/SymbolReentrancyTest.sol";
import {TotalReentrancyTest} from "../methods/silo/TotalReentrancyTest.sol";
import {TotalAssetsReentrancyTest} from "../methods/silo/TotalAssetsReentrancyTest.sol";
import {TotalSupplyReentrancyTest} from "../methods/silo/TotalSupplyReentrancyTest.sol";
import {TransferReentrancyTest} from "../methods/silo/TransferReentrancyTest.sol";
import {TransferFromReentrancyTest} from "../methods/silo/TransferFromReentrancyTest.sol";
import {TransitionCollateralReentrancyTest} from "../methods/silo/TransitionCollateralReentrancyTest.sol";
import {UpdateHooksReentrancyTest} from "../methods/silo/UpdateHooksReentrancyTest.sol";
import {UtilaztionDataReentrancyTest} from "../methods/silo/UtilaztionDataReentrancyTest.sol";
import {WithdrawReentrancyTest} from "../methods/silo/WithdrawReentrancyTest.sol";
import {WithdrawWithTypeReentrancyTest} from "../methods/silo/WithdrawWithTypeReentrancyTest.sol";
import {WithdrawFeesReentrancyTest} from "../methods/silo/WithdrawFeesReentrancyTest.sol";

contract SiloMethodsRegistry is IMethodsRegistry {
    mapping(bytes4 methodSig => IMethodReentrancyTest) public methods;
    bytes4[] public supportedMethods;

    constructor() {
        _registerMethod(new AccrueInterestReentrancyTest());
        _registerMethod(new AccrueInterestForConfigReentrancyTest());
        _registerMethod(new AllowanceReentrancyTest());
        _registerMethod(new ApproveReentrancyTest());
        _registerMethod(new AssetReentrancyTest());
        _registerMethod(new BalanceOfReentrancyTest());
        _registerMethod(new BorrowReentrancyTest());
        _registerMethod(new BorrowSameAssetReentrancyTest());
        _registerMethod(new BorrowSharesReentrancyTest());
        _registerMethod(new CallOnBehalfOfSiloReentrancyTest());
        _registerMethod(new ConfigReentrancyTest());
        _registerMethod(new ConvertToAssetsReentrancyTest());
        _registerMethod(new ConvertToAssetsWithTypeReentrancyTest());
        _registerMethod(new ConvertToSharesReentrancyTest());
        _registerMethod(new ConvertToSharesWithTypeReentrancyTest());
        _registerMethod(new DecimalsReentrancyTest());
        _registerMethod(new DepositReentrancyTest());
        _registerMethod(new DepositWithTypeReentrancyTest());
        _registerMethod(new FactoryReentrancyTest());
        _registerMethod(new FlashFeeReentrancyTest());
        _registerMethod(new FlashLoanReentrancyTest());
        _registerMethod(new GetCollateralAndDebtAssetsReentrancyTest());
        _registerMethod(new GetCollateralAndProtectedAssetsReentrancyTest());
        _registerMethod(new GetCollateralAssetsReentrancyTest());
        _registerMethod(new GetDebtAssetsReentrancyTest());
        _registerMethod(new GetLiquidityReentrancyTest());
        _registerMethod(new InitializeReentrancyTest());
        _registerMethod(new IsSolventReentrancyTest());
        _registerMethod(new LeverageSameAssetReentrancyTest());
        _registerMethod(new MaxBorrowReentrancyTest());
        _registerMethod(new MaxBorrowSameAssetReentrancyTest());
        _registerMethod(new MaxBorrowSharesReentrancyTest());
        _registerMethod(new MaxDepositReentrancyTest());
        _registerMethod(new MaxDepositWithTypeReentrancyTest());
        _registerMethod(new MaxFlashLoanReentrancyTest());
        _registerMethod(new MaxMintReentrancyTest());
        _registerMethod(new MaxMintWithTypeReentrancyTest());
        _registerMethod(new MaxRedeemReentrancyTest());
        _registerMethod(new MaxRedeemWithTypeReentrancyTest());
        _registerMethod(new MaxRepayReentrancyTest());
        _registerMethod(new MaxRepaySharesReentrancyTest());
        _registerMethod(new MaxWithdrawReentrancyTest());
        _registerMethod(new MaxWithdrawWithTypeReentrancyTest());
        _registerMethod(new MintReentrancyTest());
        _registerMethod(new MintWithTypeReentrancyTest());
        _registerMethod(new NameReentrancyTest());
        _registerMethod(new PreviewBorrowReentrancyTest());
        _registerMethod(new PreviewBorrowSharesReentrancyTest());
        _registerMethod(new PreviewDepositReentrancyTest());
        _registerMethod(new PreviewDepositWithTypeReentrancyTest());
        _registerMethod(new PreviewMintReentrancyTest());
        _registerMethod(new PreviewMintWithTypeReentrancyTest());
        _registerMethod(new PreviewRedeemReentrancyTest());
        _registerMethod(new PreviewRedeemWithTypeReentrancyTest());
        _registerMethod(new PreviewRepayReentrancyTest());
        _registerMethod(new PreviewRepaySharesReentrancyTest());
        _registerMethod(new PreviewWithdrawReentrancyTest());
        _registerMethod(new PreviewWithdrawWithTypeReentrancyTest());
        _registerMethod(new RedeemReentrancyTest());
        _registerMethod(new RedeemWithTypeReentrancyTest());
        _registerMethod(new RepayReentrancyTest());
        _registerMethod(new RepaySharesReentrancyTest());
        _registerMethod(new SharedStorageReentrancyTest());
        _registerMethod(new SiloDataStorageReentrancyTest());
        _registerMethod(new SwitchCollateralToThisSiloReentrancyTest());
        _registerMethod(new SymbolReentrancyTest());
        _registerMethod(new TotalReentrancyTest());
        _registerMethod(new TotalAssetsReentrancyTest());
        _registerMethod(new TotalSupplyReentrancyTest());
        _registerMethod(new TransferReentrancyTest());
        _registerMethod(new TransferFromReentrancyTest());
        _registerMethod(new TransitionCollateralReentrancyTest());
        _registerMethod(new UpdateHooksReentrancyTest());
        _registerMethod(new UtilaztionDataReentrancyTest());
        _registerMethod(new WithdrawReentrancyTest());
        _registerMethod(new WithdrawWithTypeReentrancyTest());
        _registerMethod(new WithdrawFeesReentrancyTest());
    }

    function supportedMethodsLength() external view returns (uint256) {
        return supportedMethods.length;
    }

    function abiFile() external pure returns (string memory) {
        return "/cache/foundry/out/silo-core/Silo.sol/Silo.json";
    }

    function _registerMethod(IMethodReentrancyTest method) internal {
        methods[method.methodSignature()] = method;
        supportedMethods.push(method.methodSignature());
    }
}
