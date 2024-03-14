// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import "../../_mocks/TokenMock.sol";

// forge test -vv --mc BorrowPossibleTest
contract BorrowPossibleTest is Test {
    /*
    forge test -vv --mt test_borrowPossible_borrowable_zeros
    */
    function test_borrowPossible_borrowable_zeros() public {
        TokenMock protectedShareToken = new TokenMock(address(0x111));
        TokenMock collateralShareToken = new TokenMock(address(0x222));
        TokenMock debtShareToken = new TokenMock(address(0x333));
        address borrower = address(0x333);

        protectedShareToken.balanceOfMock(borrower, 0);
        collateralShareToken.balanceOfMock(borrower, 0);

        (
            bool possible, uint256 protectedSharesToWithdraw, uint256 collateralSharesToWithdraw
        ) = SiloLendingLib.borrowPossible(
            protectedShareToken.ADDRESS(), collateralShareToken.ADDRESS(), debtShareToken.ADDRESS(), borrower
        );

        assertTrue(possible, "borrow possible when borrowPossible=true and no collateral in this token");
        assertEq(protectedSharesToWithdraw, 0);
        assertEq(collateralSharesToWithdraw, 0);
    }

    /*
    forge test -vv --mt test_borrowPossible_notPossibleWithDebt
    */
    function test_borrowPossible_notPossibleWithDebt() public {
        TokenMock protectedShareToken = new TokenMock(address(0x111));
        TokenMock collateralShareToken = new TokenMock(address(0x222));
        TokenMock debtShareToken = new TokenMock(address(0x333));
        address borrower = address(0x333);

        protectedShareToken.balanceOfMock(borrower, 0);
        collateralShareToken.balanceOfMock(borrower, 2);
        debtShareToken.balanceOfMock(borrower, 1);

        (
            bool possible, uint256 protectedSharesToWithdraw, uint256 collateralSharesToWithdraw
        ) = SiloLendingLib.borrowPossible(
            protectedShareToken.ADDRESS(), collateralShareToken.ADDRESS(), debtShareToken.ADDRESS(), borrower
        );

        assertFalse(possible, "borrow NOT possible when debt");
        assertEq(protectedSharesToWithdraw, 0);
        assertEq(collateralSharesToWithdraw, 2);
    }

    /*
    forge test -vv --mt test_borrowPossible_possibleWithWithdraw
    */
    function test_borrowPossible_possibleWithWithdraw() public {
        TokenMock protectedShareToken = new TokenMock(address(0x111));
        TokenMock collateralShareToken = new TokenMock(address(0x222));
        TokenMock debtShareToken = new TokenMock(address(0x333));
        address borrower = address(0x333);

        protectedShareToken.balanceOfMock(borrower, 3);
        collateralShareToken.balanceOfMock(borrower, 2);
        debtShareToken.balanceOfMock(borrower, 0);

        (
            bool possible, uint256 protectedSharesToWithdraw, uint256 collateralSharesToWithdraw
        ) = SiloLendingLib.borrowPossible(
            protectedShareToken.ADDRESS(), collateralShareToken.ADDRESS(), debtShareToken.ADDRESS(), borrower
        );

        assertTrue(possible, "borrow possible (when no debt) conditionally, with withdraw");
        assertEq(protectedSharesToWithdraw, 3);
        assertEq(collateralSharesToWithdraw, 2);
    }
}
