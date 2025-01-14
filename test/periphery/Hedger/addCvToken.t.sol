// SPDX-License-Identifier: TBD
pragma solidity 0.8.19;

import {HedgerTest} from "./HedgerTest.sol";

import {Id as MorphoId} from "morpho-blue-1.0.0/interfaces/IMorpho.sol";

contract AddCvTokenTest is HedgerTest {
    // given the caller is not the owner
    //  [X] it reverts
    // given the cvToken is zero
    //  [X] it reverts
    // given the cvMarket ID is zero
    //  [X] it reverts
    // given the cvMarket ID does not correspond to the cvToken
    //  [X] it reverts
    // given the cvMarket ID does not correspond to the MGST token
    //  [X] it reverts
    // given the cvMarket ID does not exist
    //  [X] it reverts
    // given the cvMarket ID is already set
    //  [X] it overwrites the cvToken and cvMarket ID in the whitelist
    // [X] it adds the cvToken and cvMarket ID to the whitelist

    function test_callerIsNotOwner_reverts() public {
        // Expect revert
        _expectNotOwner();

        // Call
        hedger.addCvToken(address(0), bytes32(0));
    }

    function test_cvTokenIsZero_reverts() public {
        // Expect revert
        _expectInvalidParam("cvToken");

        // Call
        hedger.addCvToken(address(0), MorphoId.unwrap(mgstMarket));
    }

    function test_cvMarketIdIsZero_reverts() public {
        // Expect revert
        _expectInvalidParam("cvMarket");

        // Call
        hedger.addCvToken(debtToken, bytes32(0));
    }

    function test_collateralTokenMismatch_reverts() public {
        // Expect revert
        _expectInvalidParam("collateral");

        // Call
        hedger.addCvToken(address(reserve), MorphoId.unwrap(mgstMarket));
    }

    function test_loanTokenMismatch_reverts() public {
        // Create another Morpho market with a different loan token
        MorphoId newMarket = _createMorphoMarket(address(reserve), debtToken, debtToken);

        // Expect revert
        _expectInvalidParam("loan");

        // Call
        hedger.addCvToken(debtToken, MorphoId.unwrap(newMarket));
    }

    function test_marketDoesNotExist_reverts() public {
        // Get a market ID that does not exist
        (, MorphoId marketId) = _getMorphoMarketId(address(reserve), debtToken, debtToken);

        // Expect revert
        _expectInvalidParam("market");

        // Call
        hedger.addCvToken(debtToken, MorphoId.unwrap(marketId));
    }

    function test_alreadyInWhitelist()
        public
        givenDebtTokenMorphoMarketIsCreated
        givenDebtTokenIsWhitelisted
    {
        // Call
        vm.prank(OWNER);
        hedger.addCvToken(debtToken, MorphoId.unwrap(debtTokenMarket));

        // Assert
        assertEq(
            MorphoId.unwrap(hedger.cvMarkets(debtToken)),
            MorphoId.unwrap(debtTokenMarket),
            "cvMarkets[debtToken]"
        );
    }

    function test_addCvToken() public {
        // Create the market
        MorphoId newMarket = _createMorphoMarket(address(mgst), debtToken, debtToken);

        // Call
        vm.prank(OWNER);
        hedger.addCvToken(debtToken, MorphoId.unwrap(newMarket));

        // Assert
        assertEq(
            MorphoId.unwrap(hedger.cvMarkets(debtToken)),
            MorphoId.unwrap(newMarket),
            "cvMarkets[debtToken]"
        );
    }
}
