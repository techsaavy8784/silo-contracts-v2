// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {IVotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowChildChain.sol";
import {VotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/VotingEscrowChildChain.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/VotingEscrowChildChainDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VotingEscrowChildChainDeploy is CommonDeploy {
    bool internal _isMainnetSimulation = false;

    function run() public returns (IVotingEscrowChildChain votingEscrow) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address chainlinkCcipRouter = getAddress(AddrKey.CHAINLINK_CCIP_ROUTER);

        vm.startBroadcast(deployerPrivateKey);

        votingEscrow = IVotingEscrowChildChain(address(
            new VotingEscrowChildChain(
                chainlinkCcipRouter,
                _sourceChainSelector()
            )
        ));

        vm.stopBroadcast();

        _registerDeployment(address(votingEscrow), VeSiloContracts.VOTING_ESCROW_CHILD_CHAIN);
    }

    function enableMainnetSimulation() public {
        _isMainnetSimulation = true;
    }

    function _sourceChainSelector() internal returns (uint64 sourceChainSelector) {
         if (isChain(ANVIL_ALIAS) || isChain(SEPOLIA_ALIAS) || _isMainnetSimulation) {
            return 1; // only for tests
         }
    }
}
