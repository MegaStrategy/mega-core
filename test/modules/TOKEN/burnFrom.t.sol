// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TokenTest} from "./TokenTest.sol";
import {TOKENv1} from "src/modules/TOKEN/MSTR.sol";

contract BurnFromTest is TokenTest {
    // when the module is not locally active
    //  [X] it reverts
    // when the caller is not permissioned
    //  [X] it reverts
    // when the amount is 0
    //  [X] it reverts
    // when the from address's allowance for the caller is insufficient
    //  [X] it reverts
    // when the from address's balance is insufficient
    //  [X] it reverts
    // when the caller's allowance for the from address is the max allowance
    //  [X] the allowance is not updated
    // [X] the from address's allowance for the caller is updated
    // [X] the total supply is decreased by the amount
    // [X] the amount is burned from the from address
    // [X] the Burn event is emitted

    function test_moduleNotActive_reverts() public givenModuleIsInstalled givenModuleIsInactive {
        vm.expectRevert(abi.encodeWithSelector(TOKENv1.TOKEN_NotActive.selector));

        vm.prank(godmode);
        mstr.burnFrom(USER, 100);
    }

    function test_amountIsZero_reverts() public givenModuleIsInstalled givenModuleIsActive {
        vm.expectRevert(abi.encodeWithSelector(TOKENv1.TOKEN_ZeroAmount.selector));

        vm.prank(godmode);
        mstr.burnFrom(USER, 0);
    }

    function test_fromAddressAllowanceInsufficient_reverts()
        public
        givenModuleIsInstalled
        givenModuleIsActive
        increaseGodmodeMintApproval(1e18)
        mint(USER, 1e18)
    {
        // Insufficient allowance
        vm.prank(USER);
        mstr.approve(godmode, 1e18 - 1);

        vm.expectRevert("ERC20: insufficient allowance");

        vm.prank(godmode);
        mstr.burnFrom(USER, 1e18);
    }

    function test_insufficientBalance_reverts()
        public
        givenModuleIsInstalled
        givenModuleIsActive
        increaseGodmodeMintApproval(1e18)
        mint(USER, 1e18)
    {
        // Sufficient allowance
        vm.prank(USER);
        mstr.approve(godmode, 1e18 + 1);

        // Insufficient balance
        vm.expectRevert("ERC20: burn amount exceeds balance");

        vm.prank(godmode);
        mstr.burnFrom(USER, 1e18 + 1);
    }

    function test_maxAllowance(
        uint256 burnAmount_
    )
        public
        givenModuleIsInstalled
        givenModuleIsActive
        increaseGodmodeMintApproval(1e18)
        mint(USER, 1e18)
    {
        uint256 burnAmount = bound(burnAmount_, 1, 1e18);

        // Sufficient allowance
        vm.prank(USER);
        mstr.approve(godmode, type(uint256).max);

        // Call
        vm.prank(godmode);
        mstr.burnFrom(USER, burnAmount);

        // Assert
        assertEq(mstr.allowance(USER, godmode), type(uint256).max, "allowance");
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

        // Sufficient allowance
        vm.prank(USER);
        mstr.approve(godmode, 1e18);

        // Expect event
        vm.expectEmit();
        emit Burn(godmode, USER, burnAmount);

        // Call
        vm.prank(godmode);
        mstr.burnFrom(USER, burnAmount);

        // Assert
        assertEq(mstr.balanceOf(USER), 1e18 - burnAmount, "balance");
        assertEq(mstr.totalSupply(), 1e18 - burnAmount, "totalSupply");
        assertEq(mstr.allowance(USER, godmode), 1e18 - burnAmount, "allowance");
    }
}
