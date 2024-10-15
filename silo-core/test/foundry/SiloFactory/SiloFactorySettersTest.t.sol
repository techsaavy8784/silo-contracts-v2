// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory, SiloFactory} from "silo-core/contracts/SiloFactory.sol";

/*
forge test -vv --mc SiloFactorySettersTest
*/
contract SiloFactorySettersTest is Test {
    SiloFactory public siloFactory;

    address siloImpl = address(100001);
    address shareCollateralTokenImpl = address(100002);
    address shareDebtTokenImpl = address(100003);
    uint256 daoFee = 0.20e18;
    address daoFeeReceiver = address(100004);

    address hacker = makeAddr("Hacker");

    function setUp() public {
        siloFactory = new SiloFactory(daoFee, daoFeeReceiver);
    }

    /*
    forge test -vv --mt test_setDaoFee
    */
    function test_setDaoFee(uint256 _newDaoFee) public {
        uint256 maxFee = siloFactory.MAX_FEE();

        vm.assume(_newDaoFee <= maxFee);

        vm.expectRevert(ISiloFactory.MaxFeeExceeded.selector);
        siloFactory.setDaoFee(maxFee + 1);

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));
        siloFactory.setDaoFee(_newDaoFee);

        siloFactory.setDaoFee(_newDaoFee);

        assertEq(siloFactory.daoFee(), _newDaoFee);
    }

    /*
    forge test -vv --mt test_setMaxDeployerFee
    */
    function test_setMaxDeployerFee(uint256 _newMaxDeployerFee) public {
        uint256 maxFee = siloFactory.MAX_FEE();

        vm.assume(_newMaxDeployerFee <= maxFee);

        vm.expectRevert(ISiloFactory.MaxFeeExceeded.selector);
        siloFactory.setMaxDeployerFee(maxFee + 1);

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));
        siloFactory.setMaxDeployerFee(_newMaxDeployerFee);

        siloFactory.setMaxDeployerFee(_newMaxDeployerFee);

        assertEq(siloFactory.maxDeployerFee(), _newMaxDeployerFee);
    }

    /*
    forge test -vv --mt test_setMaxFlashloanFee
    */
    function test_setMaxFlashloanFee(uint256 _newMaxFlashloanFee) public {
        uint256 maxFee = siloFactory.MAX_FEE();

        vm.assume(_newMaxFlashloanFee <= maxFee);

        vm.expectRevert(ISiloFactory.MaxFeeExceeded.selector);
        siloFactory.setMaxFlashloanFee(maxFee + 1);

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));
        siloFactory.setMaxFlashloanFee(_newMaxFlashloanFee);

        siloFactory.setMaxFlashloanFee(_newMaxFlashloanFee);

        assertEq(siloFactory.maxFlashloanFee(), _newMaxFlashloanFee);
    }

    /*
    forge test -vv --mt test_setMaxLiquidationFee
    */
    function test_setMaxLiquidationFee(uint256 _newMaxLiquidationFee) public {
        uint256 maxFee = siloFactory.MAX_FEE();

        vm.assume(_newMaxLiquidationFee <= maxFee);

        vm.expectRevert(ISiloFactory.MaxFeeExceeded.selector);
        siloFactory.setMaxLiquidationFee(maxFee + 1);

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));
        siloFactory.setMaxLiquidationFee(_newMaxLiquidationFee);

        siloFactory.setMaxLiquidationFee(_newMaxLiquidationFee);

        assertEq(siloFactory.maxLiquidationFee(), _newMaxLiquidationFee);
    }

    /*
    forge test -vv --mt test_setDaoFeeReceiver
    */
    function test_setDaoFeeReceiver(address _newDaoFeeReceiver) public {
        vm.assume(_newDaoFeeReceiver != address(0));

        vm.expectRevert(ISiloFactory.HookIsZeroAddress.selector);
        siloFactory.setDaoFeeReceiver(address(0));

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));
        siloFactory.setDaoFeeReceiver(_newDaoFeeReceiver);

        siloFactory.setDaoFeeReceiver(_newDaoFeeReceiver);

        assertEq(siloFactory.daoFeeReceiver(), _newDaoFeeReceiver);

        address silo = makeAddr("Silo");
        address config = makeAddr("SiloConfig");

        vm.mockCall(
            silo,
            abi.encodeWithSelector(ISilo.config.selector),
            abi.encode(config)
        );

        vm.mockCall(
            config,
            abi.encodeWithSelector(ISiloConfig.SILO_ID.selector),
            abi.encode(1)
        );

        (address dao, address deployer) = siloFactory.getFeeReceivers(silo);

        assertEq(dao, _newDaoFeeReceiver);
        assertEq(deployer, address(0));
    }

    /*
    forge test -vv --mt test_setBaseURI
    */
    function test_setBaseURI(string calldata _newBaseURI) public {
        vm.assume(keccak256(bytes(_newBaseURI)) != keccak256(bytes(siloFactory.baseURI())));

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, hacker));
        siloFactory.setBaseURI(_newBaseURI);

        siloFactory.setBaseURI(_newBaseURI);
        assertEq(siloFactory.baseURI(), _newBaseURI);
    }
}
