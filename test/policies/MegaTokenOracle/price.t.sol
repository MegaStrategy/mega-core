// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";

import {MockERC20} from "@solmate-6.8.0/test/utils/mocks/MockERC20.sol";
import {MockPriceV2} from "test/mocks/MockPriceV2.sol";

import {Actions, Kernel} from "src/Kernel.sol";
import {TOKENv1} from "src/modules/TOKEN/TOKEN.v1.sol";
import {MegaToken} from "src/modules/TOKEN/MegaToken.sol";
import {MegaTokenOracle} from "src/policies/MegaTokenOracle.sol";
import {IMegaTokenOracle} from "src/policies/interfaces/IMegaTokenOracle.sol";

contract OraclePriceTest is Test {
    Kernel public kernel;
    MockPriceV2 public PRICE;
    TOKENv1 public TOKEN;
    MegaTokenOracle public tokenOracle;

    MockERC20 public loanToken;

    uint256 public constant TOKEN_PRICE = 321e18;
    uint256 public constant LOAN_TOKEN_PRICE = 1e18;

    function setUp() public {
        kernel = new Kernel();
        TOKEN = new MegaToken(kernel, "MGST", "MGST");

        // Install modules/policies
        kernel.executeAction(Actions.InstallModule, address(TOKEN));
    }

    modifier givenPriceDecimals(
        uint8 decimals_
    ) {
        PRICE = new MockPriceV2(kernel, decimals_);
        kernel.executeAction(Actions.InstallModule, address(PRICE));
        _;
    }

    modifier givenLoanToken(
        uint8 decimals_
    ) {
        loanToken = new MockERC20("LoanToken", "LT", decimals_);
        tokenOracle = new MegaTokenOracle(kernel, address(loanToken));
        kernel.executeAction(Actions.ActivatePolicy, address(tokenOracle));
        _;
    }

    modifier givenPriceIsSet(address asset_, uint256 price_) {
        PRICE.setPrice(asset_, price_);
        _;
    }

    // given the loan token decimals are 18
    //  [X] it returns the correct price
    // given the loan token decimals are 6
    //  [X] it returns the correct price
    // given PRICE is configured with a decimal scale not 18
    //  [X] it reverts

    // TOKEN is always 18 decimals, so we don't need to scale that price

    function test_constructor() public givenPriceDecimals(18) givenLoanToken(18) {
        assertEq(tokenOracle.getLoanToken(), address(loanToken), "loan token");
        assertEq(tokenOracle.getCollateralToken(), address(TOKEN), "collateral token");
    }

    function test_loanDecimals18()
        public
        givenPriceDecimals(18)
        givenLoanToken(18)
        givenPriceIsSet(address(loanToken), LOAN_TOKEN_PRICE)
        givenPriceIsSet(address(TOKEN), TOKEN_PRICE)
    {
        uint256 price = tokenOracle.price();

        // Collateral (TOKEN) price = 321e18 (PRICE decimals = 18)
        // Loan token price = 1e18 (PRICE decimals = 18)
        // Price = # loan tokens per collateral token = 321e18
        // Scale = 36 + loan decimals - collateral decimals
        // = 36 + 18 - 18 = 36

        assertEq(price, 321e36, "price");
    }

    function test_loanDecimals6()
        public
        givenPriceDecimals(18)
        givenLoanToken(6)
        givenPriceIsSet(address(loanToken), LOAN_TOKEN_PRICE)
        givenPriceIsSet(address(TOKEN), TOKEN_PRICE)
    {
        uint256 price = tokenOracle.price();

        // Collateral (TOKEN) price = 321e18 (PRICE decimals = 18)
        // Loan token price = 1e18 (PRICE decimals = 18)
        // Price = # loan tokens per collateral token = 321e18
        // Scale = 36 + loan decimals - collateral decimals
        // = 36 + 6 - 18 = 24
        // Price = 321e24

        assertEq(price, 321e24, "price");
    }

    function test_priceDecimalsNot18() public givenPriceDecimals(17) {
        loanToken = new MockERC20("LoanToken", "LT", 18);
        tokenOracle = new MegaTokenOracle(kernel, address(loanToken));

        // Expect revert
        vm.expectRevert(
            abi.encodeWithSelector(IMegaTokenOracle.InvalidParams.selector, "PRICE decimals")
        );

        // Call
        kernel.executeAction(Actions.ActivatePolicy, address(tokenOracle));
    }
}
