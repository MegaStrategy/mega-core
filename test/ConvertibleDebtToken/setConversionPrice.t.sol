// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {ConvertibleDebtTokenTest} from "./ConvertibleDebtTokenTest.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";

contract SetConversionPriceTest is ConvertibleDebtTokenTest {
    // ========== TESTS ========== //
    // when the caller is not the issuer
    //  [X] it reverts
    // given the conversion price is already set (not zero)
    //  [X] it reverts
    // when the conversion price is zero
    //  [X] it reverts
    // it sets the conversion price

    function test_caller_notIssuer(
        address caller_
    ) public givenTokenIsCreated {
        vm.assume(caller_ != OWNER);

        vm.prank(caller_);
        vm.expectRevert(abi.encodeWithSelector(ConvertibleDebtToken.NotAuthorized.selector));
        cdt.setConversionPrice(1e18);
    }

    function test_conversionPrice_alreadySet() public givenTokenIsCreated {
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(ConvertibleDebtToken.AlreadySet.selector));
        cdt.setConversionPrice(2e18);
    }

    function test_conversionPrice_isZero_success(
        uint256 conversionPrice_
    ) public givenConversionPriceIsSet(0) givenTokenIsCreated {
        vm.assume(conversionPrice_ != 0);
        vm.prank(OWNER);
        cdt.setConversionPrice(conversionPrice_);
        vm.assertEq(cdt.conversionPrice(), conversionPrice_);
    }

    function test_conversionPriceIsZero_reverts()
        public
        givenConversionPriceIsSet(0)
        givenTokenIsCreated
    {
        // Expect revert
        vm.expectRevert(
            abi.encodeWithSelector(ConvertibleDebtToken.InvalidParam.selector, "conversionPrice")
        );

        // Call
        vm.prank(OWNER);
        cdt.setConversionPrice(0);
    }
}
