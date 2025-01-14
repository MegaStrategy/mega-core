// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TokenTest} from "./TokenTest.sol";

contract ConstructorTest is TokenTest {
    // [X] the name, symbol, and decimals are set correctly
    // [X] the module is locally active

    function test_success() public view {
        assertEq(mgst.name(), "MGST", "name");
        assertEq(mgst.symbol(), "MGST", "symbol");
        assertEq(mgst.decimals(), 18, "decimals");
        assertTrue(mgst.active(), "active");
    }
}
