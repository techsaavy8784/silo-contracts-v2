// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {ISiloLiquidityGauge} from "../interfaces/ISiloLiquidityGauge.sol";

import {BaseGaugeFactory} from "../BaseGaugeFactory.sol";

contract LiquidityGaugeFactory is BaseGaugeFactory {
    constructor(ISiloLiquidityGauge gauge) BaseGaugeFactory(address(gauge)) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @notice Deploys a new gauge for a Balancer pool.
     * @dev As anyone can register arbitrary Balancer pools with the Vault,
     * it's impossible to prove onchain that `pool` is a "valid" deployment.
     *
     * Care must be taken to ensure that gauges deployed from this factory are
     * suitable before they are added to the GaugeController.
     *
     * It is possible to deploy multiple gauges for a single pool.
     * @param relativeWeightCap The relative weight cap for the created gauge
     * @param erc20BalancesHandler The address of the pool for which to deploy a gauge
     * @return The address of the deployed gauge
     */
    function create(uint256 relativeWeightCap, address erc20BalancesHandler) external returns (address) {
        address gauge = _create();
        ISiloLiquidityGauge(gauge).initialize(relativeWeightCap, erc20BalancesHandler);
        return gauge;
    }
}
