// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

import "../../../constants/Arbitrum.sol";

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {TokensGenerator} from "../_common/TokensGenerator.sol";
import {DIAOracle, DIAOracle, IDIAOracle, IDIAOracleV2} from "../../../contracts/dia/DIAOracle.sol";
import {DIAOracleConfig} from "../../../contracts/dia/DIAOracleConfig.sol";
import {DIAConfigDefault} from "../_common/DIAConfigDefault.sol";


/*
    FOUNDRY_PROFILE=oracles forge test -vv --match-contract DIAOracleTest
*/
contract DIAOracleTest is DIAConfigDefault {
    uint256 constant TEST_BLOCK = 124937740;

    DIAOracle public immutable DIA_ORACLE;

    constructor() TokensGenerator(BlockChain.ARBITRUM) {
        initFork(TEST_BLOCK);

        DIAOracleConfig cfg = new DIAOracleConfig(_defaultDIAConfig(), false, 10 ** (18 + 8 - 18), 0, "RDPX/USD");
        DIA_ORACLE = new DIAOracle();
        DIA_ORACLE.initialize(cfg);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_DIAOracle_initialize
    */
    function test_DIAOracle_initialize_InvalidKey() public {
        DIAOracle newOracle = new DIAOracle();
        IDIAOracle.DIAConfig memory cfg = _defaultDIAConfig();

        DIAOracleConfig newConfig = new DIAOracleConfig(cfg, false, 10 ** (18 + 8 - 18), 0, "aaa");

        vm.expectRevert(IDIAOracle.InvalidKey.selector);
        newOracle.initialize(newConfig);
    }

    function test_DIAOracle_initialize_OldPrice() public {
        DIAOracle newOracle = new DIAOracle();
        IDIAOracle.DIAConfig memory cfg = _defaultDIAConfig();

        cfg.heartbeat = 1856;
        DIAOracleConfig newConfig = new DIAOracleConfig(cfg, false, 10 ** (18 + 8 - 18), 0, "RDPX/USD");

        vm.expectRevert(IDIAOracle.OldPrice.selector);
        newOracle.initialize(newConfig);
    }

    function test_DIAOracle_initialize_OldPriceEth() public {
        DIAOracle newOracle = new DIAOracle();
        IDIAOracle.DIAConfig memory cfg = _defaultDIAConfig();

        // at the block from test, price is 1856s old
        // and ETH price is 6306s old
        cfg.heartbeat = 1857;
        bool quoteIsEth = true;

        DIAOracleConfig newConfig = new DIAOracleConfig(cfg, quoteIsEth, 10 ** (18 + 8 - 18), 0, "RDPX/USD");

        vm.expectRevert(IDIAOracle.OldPriceEth.selector);
        newOracle.initialize(newConfig);
    }

    function test_DIAOracle_initialize_pass() public {
        DIAOracle newOracle = new DIAOracle();
        IDIAOracle.DIAConfig memory cfg = _defaultDIAConfig();

        DIAOracleConfig newConfig = new DIAOracleConfig(cfg, false, 10 ** (18 + 8 - 18), 0, "RDPX/USD");

        newOracle.initialize(newConfig);
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_DIAOracle_quoteView_pass
    */
    function test_DIAOracle_quoteView_inUSDT() public {
        uint256 price = DIA_ORACLE.quoteView(1e18, address(tokens["RDPX"]));
        emit log_named_decimal_uint("RDPX/USD", price, 18);
        assertEq(price, 17889972650000000000, "$17,88");
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_DIAOracle_quoteView_inUSDC
    */
    function test_DIAOracle_quoteView_inUSDC() public {
        IDIAOracle.DIAConfig memory cfg = _defaultDIAConfig();
        cfg.quoteToken = IERC20Metadata(address(tokens["USDC"]));
        DIAOracleConfig oracleConfig = new DIAOracleConfig(_defaultDIAConfig(), false, 10 ** (18 + 8 - 6), 0, "RDPX/USD");
        DIAOracle oracle = new DIAOracle();
        oracle.initialize(oracleConfig);

        uint256 price = oracle.quoteView(1e18, address(tokens["RDPX"]));
        emit log_named_decimal_uint("RDPX/USD", price, 6);
        assertEq(price, 17889972, "$17,88");
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_DIAOracle_quoteView_AssetNotSupported
    */
    function test_DIAOracle_quoteView_AssetNotSupported() public {
        vm.expectRevert(IDIAOracle.AssetNotSupported.selector);
        DIA_ORACLE.quoteView(1e18, address(1));
    }

    /*
        FOUNDRY_PROFILE=oracles forge test -vvv --mt test_DIAOracle_quoteView_AssetNotSupported
    */
    function test_DIAOracle_quoteView_BaseAmountOverflow() public {
        vm.expectRevert(IDIAOracle.BaseAmountOverflow.selector);
        DIA_ORACLE.quoteView(2 ** 128, address(tokens["RDPX"]));
    }

    function test_DIAOracle_quoteToken() public {
        assertEq(address(DIA_ORACLE.quoteToken()), address(tokens["USDT"]), "must be USDC");
    }
}
