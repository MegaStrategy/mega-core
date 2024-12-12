// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Banker} from "src/policies/Banker.sol";
import {ROLESv1} from "src/modules/ROLES/ROLES.v1.sol";
import {ConvertibleDebtToken} from "src/lib/ConvertibleDebtToken.sol";
import {Timestamp} from "axis-core-1.0.1/lib/Timestamp.sol";
import {ERC20} from "solmate-6.8.0/tokens/ERC20.sol";

import {BankerTest} from "./BankerTest.sol";

contract BankerCreateTokenTest is BankerTest {
    using Timestamp for uint48;

    // test cases
    // [X] when the policy is not active
    //     [X] it reverts
    // [X] when the caller is not permissioned
    //     [X] it reverts
    // [X] when the asset is the zero address
    //     [X] it reverts
    // [X] when the asset is not a valid ERC20
    //     [X] it reverts
    // [X] when the maturity is not in the future
    //     [X] it reverts
    // [X] when the conversion price is zero
    //     [X] it reverts
    // [X] when the parameters are valid
    //     [X] it creates a ConvertibleDebtToken with the given parameters
    //     [X] it stores the debt token address in the createdBy mapping
    //     [X] the token name is Convertible + underlying name + Series N
    //     [X] the token symbol is cv + the underlying symbol + -N

    function test_policyNotActive_reverts() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Banker.Inactive.selector));
        banker.createDebtToken(
            debtTokenParams.underlying, debtTokenParams.maturity, debtTokenParams.conversionPrice
        );
    }

    function test_callerNotPermissioned_reverts(
        address caller_
    ) public givenPolicyIsActive {
        vm.assume(caller_ != manager);

        vm.prank(caller_);
        vm.expectRevert(
            abi.encodeWithSelector(ROLESv1.ROLES_RequireRole.selector, bytes32("manager"))
        );
        banker.createDebtToken(
            debtTokenParams.underlying, debtTokenParams.maturity, debtTokenParams.conversionPrice
        );
    }

    function test_asset_zeroAddress_reverts() public givenPolicyIsActive {
        vm.prank(manager);
        vm.expectRevert();
        banker.createDebtToken(
            address(0), debtTokenParams.maturity, debtTokenParams.conversionPrice
        );
    }

    function test_asset_notERC20_reverts() public givenPolicyIsActive {
        vm.prank(manager);
        vm.expectRevert();
        banker.createDebtToken(
            address(this), debtTokenParams.maturity, debtTokenParams.conversionPrice
        );
    }

    function test_maturity_notInFuture_reverts(
        uint48 maturity_
    ) public givenPolicyIsActive {
        uint48 maturity = uint48(bound(maturity_, 0, block.timestamp));

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(ConvertibleDebtToken.InvalidParam.selector, "maturity")
        );
        banker.createDebtToken(
            debtTokenParams.underlying, maturity, debtTokenParams.conversionPrice
        );
    }

    function test_conversionPrice_zero_reverts() public givenPolicyIsActive {
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(ConvertibleDebtToken.InvalidParam.selector, "conversionPrice")
        );
        banker.createDebtToken(debtTokenParams.underlying, debtTokenParams.maturity, 0);
    }

    function test_success(uint256 maturity_, uint256 conversionPrice_) public givenPolicyIsActive {
        uint48 maturity = uint48(bound(maturity_, block.timestamp + 1, type(uint48).max));
        uint256 conversionPrice = bound(conversionPrice_, 1, type(uint256).max);

        vm.prank(manager);
        address debtToken =
            banker.createDebtToken(debtTokenParams.underlying, maturity, conversionPrice);

        // Confirm the debt token's parameters are correct
        ConvertibleDebtToken cdt = ConvertibleDebtToken(debtToken);
        assertEq(address(cdt.underlying()), debtTokenParams.underlying);
        assertEq(cdt.maturity(), maturity);
        assertEq(cdt.conversionPrice(), conversionPrice);

        // Check the name and symbol of the debt token
        string memory expectedName = string(
            abi.encodePacked(
                "Convertible ", ERC20(debtTokenParams.underlying).name(), " - Series 1"
            )
        );

        string memory expectedSymbol =
            string(abi.encodePacked("cv", ERC20(debtTokenParams.underlying).symbol(), "-1"));

        assertEq(cdt.name(), expectedName);
        assertEq(cdt.symbol(), expectedSymbol);

        // Check the debt token was stored in the createdBy mapping
        assertTrue(banker.createdBy(debtToken));
    }
}
