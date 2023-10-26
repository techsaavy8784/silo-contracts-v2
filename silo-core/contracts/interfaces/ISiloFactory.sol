// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC721Upgradeable} from "openzeppelin-contracts-upgradeable/interfaces/IERC721Upgradeable.sol";
import {ISiloConfig} from "./ISiloConfig.sol";

interface ISiloFactory is IERC721Upgradeable {
    event NewSilo(address indexed token0, address indexed token1, address silo0, address silo1, address siloConfig);
    event DaoFeeChanged(uint256 daoFee);
    event MaxDeployerFeeChanged(uint256 maxDeployerFee);
    event MaxFlashloanFeeChanged(uint256 maxFlashloanFee);
    event MaxLiquidationFeeChanged(uint256 maxLiquidationFee);
    event DaoFeeReceiverChanged(address daoFeeReceiver);

    error ZeroAddress();
    error MaxFee();
    error SameAsset();
    error InvalidIrm();
    error InvalidMaxLtv();
    error InvalidMaxLt();
    error InvalidLt();
    error InvalidDeployer();
    error MaxDeployerFee();
    error MaxFlashloanFee();
    error MaxLiquidationFee();
    error InvalidIrmConfig();
    error InvalidFee();
    error BeforeCall();
    error OracleMisconfiguration();

    function initialize(
        address _siloImpl,
        address _shareCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFee,
        address _daoFeeReceiver
    ) external;

    /// @dev share tokens in _configData are overridden so can be set to address(0). Sanity data validation
    ///      is done by SiloConfig.
    /// @param _initData silo initialization data
    function createSilo(ISiloConfig.InitData memory _initData) external returns (ISiloConfig siloConfig);

    function setDaoFee(uint256 _newDaoFee) external;
    function setDaoFeeReceiver(address _newDaoFeeReceiver) external;
    function setMaxDeployerFee(uint256 _newMaxDeployerFee) external;
    function setMaxFlashloanFee(uint256 _newMaxFlashloanFee) external;
    function setMaxLiquidationFee(uint256 _newMaxLiquidationFee) external;

    function daoFee() external view returns (uint256);
    function maxDeployerFee() external view returns (uint256);
    function maxFlashloanFee() external view returns (uint256);
    function maxLiquidationFee() external view returns (uint256);
    function daoFeeReceiver() external view returns (address);
    function siloImpl() external view returns (address);
    function shareCollateralTokenImpl() external view returns (address);
    function shareDebtTokenImpl() external view returns (address);

    function idToSilos(uint256 _id) external view returns (address[2] memory);
    function siloToId(address _silo) external view returns (uint256);

    function isSilo(address _silo) external view returns (bool);
    function getNextSiloId() external view returns (uint256);
    function getFeeReceivers(address _silo) external view returns (address dao, address deployer);

    function validateSiloInitData(ISiloConfig.InitData memory _initData) external view returns (bool);
}
