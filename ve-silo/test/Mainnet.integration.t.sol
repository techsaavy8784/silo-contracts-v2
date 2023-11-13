// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {MainnetDeploy} from "ve-silo/deploy/MainnetDeploy.s.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

import {ISiloGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {ISmartWalletChecker} from "ve-silo/contracts/voting-escrow/interfaces/ISmartWalletChecker.sol";
import {IExtendedOwnable} from "ve-silo/contracts/access/IExtendedOwnable.sol";
import {ISiloTimelockController} from "ve-silo/contracts/governance/interfaces/ISiloTimelockController.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";
import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {IBalancerTokenAdmin} from "ve-silo/contracts/silo-tokens-minter/interfaces/IBalancerTokenAdmin.sol";
import {IBalancerMinter} from "ve-silo/contracts/silo-tokens-minter/interfaces/IBalancerMinter.sol";
import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {IHookReceiverMock as IHookReceiver} from "./_mocks/IHookReceiverMock.sol";
import {IShareTokenLike as IShareToken} from "ve-silo/contracts/gauges/interfaces/IShareTokenLike.sol";
import {ISiloMock as ISilo} from "ve-silo/test/_mocks/ISiloMock.sol";
import {IFeesManager} from "ve-silo/contracts/silo-tokens-minter/interfaces/IFeesManager.sol";

import {
    ISiloFactoryWithFeeDetails as ISiloFactory
} from "ve-silo/contracts/silo-tokens-minter/interfaces/ISiloFactoryWithFeeDetails.sol";

// solhint-disable max-states-count

// FOUNDRY_PROFILE=ve-silo forge test --mc MainnetTest --ffi -vvv
contract MainnetTest is IntegrationTest {
    using stdStorage for StdStorage;

    uint256 internal constant _WEIGHT_CAP = 1e18;
    uint256 internal constant _ERC_20_TOTAL_SUPPLY = 1000e18;
    uint256 internal constant _BOB_BALANCE = 500e18;
    uint256 internal constant _ALICE_BALANCE = 300e18;
    uint256 internal constant _JOHN_BALANCE = 100e18;
    uint256 internal constant _DAO_VOTER_BALANCE = 200_000_000e18;
    uint256 internal constant _FORKING_BLOCK_NUMBER = 17633400;
    uint256 internal constant _YEAR = 365 * 24 * 3600;
    uint256 internal constant _WEEK = 604800;
    uint256 internal constant _DAO_FEE = 1e3; // 10%
    uint256 internal constant _DEPLOYER_FEE = 2e3; // 20%

    IBalancerMinter internal _minter;
    IGaugeController internal _gaugeController;
    IBalancerTokenAdmin internal _balancerTokenAdmin;
    ILiquidityGaugeFactory internal _factory;
    IVeSilo internal _veSilo;
    ISiloTimelockController internal _timelock;
    ISiloGovernor internal _siloGovernor;
    IGaugeAdder internal _gaugeAdder;

    address internal _hookReceiver = makeAddr("Hook receiver");
    address internal _shareToken = makeAddr("Share token");
    address internal _silo = makeAddr("Silo");
    address internal _siloFactory = makeAddr("Silo Factory");
    address internal _daoFeeReceiver = makeAddr("DAO fee receiver");
    address internal _deployerFeeReceiver = makeAddr("Deployer fee receiver");
    address internal _bob = makeAddr("_bob");
    address internal _alice = makeAddr("_alice");
    address internal _john = makeAddr("_john");
    address internal _daoVoter = makeAddr("_daoVoter");
    address internal _smartValletChecker = makeAddr("_smartValletChecker");
    address internal _deployer;

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(MAINNET_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        MainnetDeploy deploy = new MainnetDeploy();
        deploy.disableDeploymentsSync();
        deploy.run();

        _veSilo = IVeSilo(getAddress(VeSiloContracts.VOTING_ESCROW));
        _timelock = ISiloTimelockController(getAddress(VeSiloContracts.TIMELOCK_CONTROLLER));
        _factory = ILiquidityGaugeFactory(getAddress(VeSiloContracts.LIQUIDITY_GAUGE_FACTORY));
        _balancerTokenAdmin = IBalancerTokenAdmin(getAddress(VeSiloContracts.BALANCER_TOKEN_ADMIN));
        _gaugeController = IGaugeController(getAddress(VeSiloContracts.GAUGE_CONTROLLER));
        _siloGovernor = ISiloGovernor(getAddress(VeSiloContracts.SILO_GOVERNOR));
        _minter = IBalancerMinter(getAddress(VeSiloContracts.MAINNET_BALANCER_MINTER));
        _gaugeAdder = IGaugeAdder(getAddress(VeSiloContracts.GAUGE_ADDER));

        vm.mockCall(
            _hookReceiver,
            abi.encodeWithSelector(IHookReceiver.shareToken.selector),
            abi.encode(_shareToken)
        );

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.silo.selector),
            abi.encode(_silo)
        );

        vm.mockCall(
            _silo,
            abi.encodeWithSelector(ISilo.factory.selector),
            abi.encode(_siloFactory)
        );
    }

    function testIt() public {
        _configureFakeSmartWalletChecker();
        _giveVeSiloTokensToUsers();
        _activeteBlancerTokenAdmin();
        address gauge = _createGauge();
        _addGauge(gauge);
        _voteForGauge(gauge);
        _updateUserBalances(ISiloLiquidityGauge(gauge));
        _checkpointUsers(ISiloLiquidityGauge(gauge));
        _verifyClaimable(ISiloLiquidityGauge(gauge));
        _getIncentives(gauge);
        _stopMiningProgram();
    }

    function _verifyClaimable(ISiloLiquidityGauge _gauge) internal {
        _mockSiloFeesDetails();

        vm.warp(block.timestamp + _WEEK + 1);

        uint256 claimableTotal;
        uint256 claimableTokens;
        uint256 feeDao;
        uint256 feeDeployer;

        claimableTotal = _gauge.claimable_tokens(_bob);
        (claimableTokens, feeDao, feeDeployer) = _gauge.claimable_tokens_with_fees(_bob);

        assertTrue(claimableTotal == (claimableTokens + feeDao + feeDeployer));

        uint256 expectedFeeDao = claimableTotal * 10 / 100;
        uint256 expectedFeeDeployer = claimableTotal * 20 / 100;
        uint256 expectedToReceive = claimableTotal - expectedFeeDao - expectedFeeDeployer;

        assertEq(expectedFeeDao, feeDao, "Wrong DAO fee");
        assertEq(expectedFeeDeployer, feeDeployer, "Wrong deployer fee");
        assertEq(expectedToReceive, claimableTokens, "Wrong number of the user tokens");
    }

    function _getUserIncentives(address _user, address _gauge) internal {
        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        assertEq(siloToken.balanceOf(_user), 0);

        vm.prank(_user);
        _minter.setMinterApproval(_user, true);
        vm.prank(_user);
        _minter.mintFor(_gauge, _user);

        assertTrue(siloToken.balanceOf(_user) != 0);

        uint256 totalMinted = _minter.minted(_user, _gauge);
        uint256 expectedMinted = totalMinted - (totalMinted * 10 / 100 + totalMinted * 20 / 100);
        uint256 mintedToUser = _minter.mintedToUser(_user, _gauge);

        assertEq(mintedToUser, expectedMinted, "Counters of minted tokens did not mutch");
    }

    function _getIncentives(address _gauge) internal {
        _mockSiloFeesDetails();

        _getUserIncentives(_bob, _gauge);
        _getUserIncentives(_alice, _gauge);
        _getUserIncentives(_john, _gauge);
    }

    function _checkpointUsers(ISiloLiquidityGauge _gauge) internal {
        assertEq(_gauge.integrate_fraction(_bob), 0);
        assertEq(_gauge.integrate_fraction(_alice), 0);
        assertEq(_gauge.integrate_fraction(_john), 0);

        vm.warp(block.timestamp + _WEEK + 1);

        vm.prank(_bob);
        _gauge.user_checkpoint(_bob);

        vm.prank(_alice);
        _gauge.user_checkpoint(_alice);

        vm.prank(_john);
        _gauge.user_checkpoint(_john);

        assertTrue(_gauge.integrate_fraction(_bob) != 0);
        assertTrue(_gauge.integrate_fraction(_alice) != 0);
        assertTrue(_gauge.integrate_fraction(_john) != 0);
    }

    function _updateBalanceInGauge(
        ISiloLiquidityGauge _gauge,
        address _user,
        uint256 _balance,
        uint256 _totalSupply
    )
        internal
    {
        vm.mockCall(
            _shareToken,
            abi.encodeCall(IShareToken.balanceOf, _user),
            abi.encode(_balance)
        );

        vm.mockCall(
            _shareToken,
            abi.encodeCall(IShareToken.balanceOfAndTotalSupply, _user),
            abi.encode(_balance, _totalSupply)
        );

        vm.prank(_hookReceiver);
        _gauge.afterTokenTransfer(
            _user,
            _balance,
            address(0),
            0,
            _totalSupply
        );
    }

    function _updateUserBalances(ISiloLiquidityGauge _gauge) internal {
        uint256 bobBalance = 500e18;
        uint256 aliceBalance = 300e18;
        uint256 johnBalance = 100e18;
        
        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.totalSupply.selector),
            abi.encode(_ERC_20_TOTAL_SUPPLY)
        );

        assertEq(_gauge.working_balances(_bob), 0);
        assertEq(_gauge.working_balances(_alice), 0);
        assertEq(_gauge.working_balances(_john), 0);

        _updateBalanceInGauge(_gauge, _bob, bobBalance, _ERC_20_TOTAL_SUPPLY);
        assertTrue(_gauge.working_balances(_bob) != 0, "An invalid working balance for Bob");

        _updateBalanceInGauge(_gauge, _alice, aliceBalance, _ERC_20_TOTAL_SUPPLY);
        assertTrue(_gauge.working_balances(_alice) != 0, "An invalid working balance for Alice");

        _updateBalanceInGauge(_gauge, _john, johnBalance, _ERC_20_TOTAL_SUPPLY);
        assertTrue(_gauge.working_balances(_john) != 0, "An invalid working balance for John");
    }

    function _voteForGauge(address _gauge) internal {
        vm.prank(_bob);
        _gaugeController.vote_for_gauge_weights(_gauge, 10000);

        vm.prank(_alice);
        _gaugeController.vote_for_gauge_weights(_gauge, 10000);

        vm.prank(_john);
        _gaugeController.vote_for_gauge_weights(_gauge, 10000);
    }

    function _addGauge(address _gauge) internal {
        address[] memory targets = new address[](6);
        targets[0] = address(_gaugeController);
        targets[1] = address(_gaugeController);
        targets[2] = address(_gaugeAdder);
        targets[3] = address(_gaugeAdder);
        targets[4] = address(_gaugeAdder);
        targets[5] = address(_gaugeAdder);

        // Empty values
        uint256[] memory values = new uint256[](6);

        // Functions inputs
        bytes[] memory calldatas = new bytes[](6);
        
        string memory gaugeTypeName = new string(64);
        gaugeTypeName = "Mainnet gauge";
        calldatas[0] = abi.encodeWithSignature("add_type(string,uint256)", gaugeTypeName, 1e18);
        calldatas[1] = abi.encodeWithSignature("set_gauge_adder(address)", address(_gaugeAdder));
        calldatas[2] = abi.encodeWithSignature("acceptOwnership()");
        calldatas[3] = abi.encodeWithSignature("addGaugeType(string)", gaugeTypeName);
        calldatas[4] = abi.encodeWithSignature("setGaugeFactory(address,string)", address(_factory), gaugeTypeName);
        calldatas[5] = abi.encodeWithSignature("addGauge(address,string)", address(_gauge), gaugeTypeName);

        _executeProposal(targets, values, calldatas);

        assertEq(_gaugeController.n_gauge_types(), 1, "An invalid number of the gauge types");
        assertEq(_gaugeController.n_gauges(), 1, "Should be 1 gauge in the gaugeController");
    }

    function _createGauge() internal returns (address gauge) {
        gauge = _factory.create(_WEIGHT_CAP, _hookReceiver);
        vm.label(gauge, "Gauge");
    }

    function _activeteBlancerTokenAdmin() internal {
        stdstore
            .target(getAddress(SILO_TOKEN))
            .sig(IExtendedOwnable.owner.selector)
            .checked_write(address(_balancerTokenAdmin));

        vm.prank(_deployer);
        _balancerTokenAdmin.activate();
    }

    function _giveVeSiloTokensToUsers() internal {
        assertEq(_veSilo.balanceOf(_bob), 0);
        assertEq(_veSilo.balanceOf(_alice), 0);
        assertEq(_veSilo.balanceOf(_john), 0);
        assertEq(_veSilo.balanceOf(_daoVoter), 0);

        uint256 lockEnd = block.timestamp + _YEAR;

        _getVeSiloTokens(_bob, _BOB_BALANCE, lockEnd);
        _getVeSiloTokens(_alice, _ALICE_BALANCE, lockEnd);
        _getVeSiloTokens(_john, _JOHN_BALANCE, lockEnd);
        _getVeSiloTokens(_daoVoter, _DAO_VOTER_BALANCE, lockEnd);

        assertTrue(_veSilo.balanceOf(_bob) != 0);
        assertTrue(_veSilo.balanceOf(_alice) != 0);
        assertTrue(_veSilo.balanceOf(_john) != 0);
        assertTrue(_veSilo.balanceOf(_daoVoter) != 0);
    }

    function _getVeSiloTokens(address _userAddr, uint256 _amount, uint256 _unlockTime) internal {
        IERC20 silo80Weth20Token = IERC20(getAddress(SILO80_WETH20_TOKEN));

        deal(address(silo80Weth20Token), _userAddr, _amount);

        vm.prank(_userAddr);
        silo80Weth20Token.approve(address(_veSilo), _amount);

        vm.prank(_userAddr);
        _veSilo.create_lock(_amount, _unlockTime);
    }

    function _configureFakeSmartWalletChecker() internal {
        vm.prank(address(_timelock));
        _veSilo.commit_smart_wallet_checker(_smartValletChecker);

        vm.prank(address(_timelock));
        _veSilo.apply_smart_wallet_checker();

        assertEq(
            _veSilo.smart_wallet_checker(),
            _smartValletChecker,
            "Failed to configure a fake smart wallet checker"
        );

        vm.mockCall(
            _smartValletChecker,
            abi.encodeCall(ISmartWalletChecker.check, _bob),
            abi.encode(true)
        );

        vm.mockCall(
            _smartValletChecker,
            abi.encodeCall(ISmartWalletChecker.check, _alice),
            abi.encode(true)
        );

        vm.mockCall(
            _smartValletChecker,
            abi.encodeCall(ISmartWalletChecker.check, _john),
            abi.encode(true)
        );

        vm.mockCall(
            _smartValletChecker,
            abi.encodeCall(ISmartWalletChecker.check, _daoVoter),
            abi.encode(true)
        );
    }

    function _mockSiloFeesDetails() internal {
        // with fees
        // 10% - to DAO
        // 20% - to deployer
        vm.mockCall(
            _siloFactory,
            abi.encodeWithSelector(ISiloFactory.getFeeReceivers.selector, _silo),
            abi.encode(
                _daoFeeReceiver,
                _deployerFeeReceiver
            )
        );

        vm.prank(_deployer);
        IFeesManager(address(_minter)).setFees(_DAO_FEE, _DEPLOYER_FEE);
    }

    // solhint-disable-next-line function-max-lines
    function _executeProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    )
        internal
    {
        string memory description = "Test proposal";

        // pushing time a little bit forward
        vm.warp(block.timestamp + 3_600);

        vm.prank(_daoVoter);

        uint256 proposalId = _siloGovernor.propose(
            targets,
            values,
            calldatas,
            description
        );

        uint256 snapshot = _siloGovernor.proposalSnapshot(proposalId);
        // pushing time to change a proposal to an active status
        vm.warp(snapshot + 3_600);

        vm.prank(_daoVoter);
        _siloGovernor.castVote(proposalId, 1);

        vm.warp(snapshot + 1 weeks + 1 seconds);

        _siloGovernor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        vm.warp(block.timestamp + 3_600);

        _siloGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );
    }

    function _stopMiningProgram() internal {
        Ownable2Step siloToken = Ownable2Step(getAddress(SILO_TOKEN));

        address siloTokenOwner = siloToken.owner();

        assertEq(siloTokenOwner, address(_balancerTokenAdmin), "_balancerTokenAdmin is not an owner");

        address owner = Ownable2Step(address(_balancerTokenAdmin)).owner();

        vm.prank(owner);
        _balancerTokenAdmin.stopMining();

        siloTokenOwner = siloToken.owner();

        assertEq(owner, siloTokenOwner, "Expect an ownership to be transferred");
    }
}
