// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TokenTest} from "./TokenTest.sol";
import {TOKENv1} from "src/modules/TOKEN/MSTR.sol";

contract BurnTest is TokenTest {
    // when the module is not locally active
    //  [X] it reverts
    // when the amount is 0
    //  [X] it reverts
    // when the caller's balance is insufficient
    //  [X] it reverts
    // [X] the caller's balance is decreased by the amount
    // [X] the total supply is decreased by the amount
    // [X] the Burn event is emitted

    function test_moduleNotActive_reverts() public givenModuleIsInstalled givenModuleIsInactive {
        vm.expectRevert(abi.encodeWithSelector(TOKENv1.TOKEN_NotActive.selector));

        vm.prank(USER);
        mstr.burn(100);
    }

    function test_amountIsZero_reverts() public givenModuleIsInstalled givenModuleIsActive {
        vm.expectRevert(abi.encodeWithSelector(TOKENv1.TOKEN_ZeroAmount.selector));

        vm.prank(USER);
        mstr.burn(0);
    }

    function test_callerBalanceInsufficient_reverts()
        public
        givenModuleIsInstalled
        givenModuleIsActive
        increaseGodmodeMintApproval(1e18)
        mint(USER, 1e18)
    {
        vm.expectRevert("ERC20: burn amount exceeds balance");

        vm.prank(USER);
        mstr.burn(1e18 + 1);
    }

    function test_success(
        uint256 burnAmount_
    )
        public
        givenModuleIsInstalled
        givenModuleIsActive
        increaseGodmodeMintApproval(1e18)
        mint(USER, 1e18)
    {
        uint256 burnAmount = bound(burnAmount_, 1, 1e18);

        // Expect event
        vm.expectEmit();
        emit Burn(USER, USER, burnAmount);

        // Call
        vm.prank(USER);
        mstr.burn(burnAmount);

        // Assert
        assertEq(mstr.balanceOf(USER), 1e18 - burnAmount, "balance");
        assertEq(mstr.totalSupply(), 1e18 - burnAmount, "total supply");
    }
}
