// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {BankerTest} from "./BankerTest.sol";

contract BankerGetNextDebtTokenNameAndSymbolTest is BankerTest {
    // given a debt token already exists for the underlying asset
    //  [X] it returns the name and symbol for the next debt token
    // [X] it returns the name and symbol starting at series 1

    function test_debtTokenDoesNotExist() public givenPolicyIsActive {
        (string memory name, string memory symbol) =
            banker.getNextDebtTokenNameAndSymbol(debtTokenParams.underlying);

        assertEq(name, "Convertible Stablecoin - Series 1", "name");
        assertEq(symbol, "cvSTBL-1", "symbol");
    }

    function test_debtTokenExists() public givenPolicyIsActive givenDebtTokenCreated {
        // Get the next debt token name and symbol
        (string memory name, string memory symbol) =
            banker.getNextDebtTokenNameAndSymbol(debtTokenParams.underlying);

        assertEq(name, "Convertible Stablecoin - Series 2", "name");
        assertEq(symbol, "cvSTBL-2", "symbol");
    }
}
