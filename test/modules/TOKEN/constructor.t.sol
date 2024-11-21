// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TokenTest} from "./TokenTest.sol";

contract ConstructorTest is TokenTest {
    // [X] the name, symbol, and decimals are set correctly
    // [X] the module is locally active

    function test_success() public view {
        assertEq(mstr.name(), "MSTR", "name");
        assertEq(mstr.symbol(), "MSTR", "symbol");
        assertEq(mstr.decimals(), 18, "decimals");
        assertTrue(mstr.active(), "active");
    }
}
