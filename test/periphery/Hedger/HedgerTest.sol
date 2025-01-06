// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {Hedger} from "src/periphery/Hedger.sol";

contract HedgerTest is Test {
    Hedger public hedger;

    function setUp() public {
        hedger = new Hedger();
    }
}
