// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

import {
    Id as MorphoId,
    MarketParams as MorphoMarketParams
} from "@morpho-blue-1.0.0/interfaces/IMorpho.sol";
import {MarketParamsLib} from "@morpho-blue-1.0.0/libraries/MarketParamsLib.sol";

import {Hedger} from "src/periphery/Hedger.sol";

contract HedgerSetMgstMarketTest is HedgerTest {
    // given the caller is not the owner
    //  [X] it reverts
    // when the market ID is zero bytes
    //  [X] it reverts
    // when the market does not exist
    //  [X] it reverts
    // when the collateral token is not the protocol token
    //  [X] it reverts
    // when the loan token is not the reserve token
    //  [X] it reverts
    // [X] it sets the market ID

    function test_callerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        hedger.setMgstMarket(0);
    }

    function test_marketIdIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Hedger.InvalidParam.selector, "zero"));

        vm.prank(OWNER);
        hedger.setMgstMarket(0);
    }

    function test_marketDoesNotExist() public {
        // Prepare market params
        MorphoMarketParams memory mgstMarketParams = MorphoMarketParams({
            loanToken: address(reserve),
            collateralToken: address(mgst),
            oracle: address(0), // Disabled
            irm: address(0), // Disabled
            lltv: LLTV + 1
        });
        bytes32 mgstMarketId = MorphoId.unwrap(MarketParamsLib.id(mgstMarketParams));

        vm.expectRevert(abi.encodeWithSelector(Hedger.InvalidParam.selector, "market"));

        vm.prank(OWNER);
        hedger.setMgstMarket(mgstMarketId);
    }

    function test_collateralTokenIsNotProtocolToken() public {
        // Prepare market params
        MorphoMarketParams memory mgstMarketParams = MorphoMarketParams({
            loanToken: address(reserve),
            collateralToken: address(reserve),
            oracle: address(0), // Disabled
            irm: address(0), // Disabled
            lltv: LLTV
        });
        bytes32 mgstMarketId = MorphoId.unwrap(MarketParamsLib.id(mgstMarketParams));

        // Create the market
        morpho.createMarket(mgstMarketParams);

        vm.expectRevert(abi.encodeWithSelector(Hedger.InvalidParam.selector, "collateral"));

        vm.prank(OWNER);
        hedger.setMgstMarket(mgstMarketId);
    }

    function test_loanTokenIsNotReserveToken() public {
        // Prepare market params
        MorphoMarketParams memory mgstMarketParams = MorphoMarketParams({
            loanToken: address(mgst),
            collateralToken: address(mgst),
            oracle: address(0), // Disabled
            irm: address(0), // Disabled
            lltv: LLTV
        });
        bytes32 mgstMarketId = MorphoId.unwrap(MarketParamsLib.id(mgstMarketParams));

        // Create the market
        morpho.createMarket(mgstMarketParams);

        vm.expectRevert(abi.encodeWithSelector(Hedger.InvalidParam.selector, "loan"));

        vm.prank(OWNER);
        hedger.setMgstMarket(mgstMarketId);
    }

    function test_success() public {
        // Prepare market params
        MorphoMarketParams memory mgstMarketParams = MorphoMarketParams({
            loanToken: address(reserve),
            collateralToken: address(mgst),
            oracle: address(0), // Disabled
            irm: address(0), // Disabled
            lltv: LLTV
        });
        bytes32 mgstMarketId = MorphoId.unwrap(MarketParamsLib.id(mgstMarketParams));

        // Market already exists

        vm.prank(OWNER);
        hedger.setMgstMarket(mgstMarketId);

        // Assert
        assertEq(MorphoId.unwrap(hedger.mgstMarket()), mgstMarketId, "mgstMarket");
    }
}
