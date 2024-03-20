// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.17;

/**
 * @title Errors library
 * @author
 * @notice
 */
library Errors {
    string public constant NOT_OWNER = "0"; // "LibDiamond: Must be contract owner"
    string public constant INCONSISTENT_PARAMS_LENGTH = "1"; // 'Array parameters that should be equal length are not'
    string public constant PRICE_VALUE_0 = "2"; // 'Price value from oracle should not be 0'
    string public constant CALLER_NOT_ASSET_LISTING_OR_POOL_ADMIN = "3"; // 'The caller of the function is not an asset listing or pool admin'
    string public constant ACCOUNT_ALREADY_ROLE = "4"; // 'The account already has the role granted'
    string public constant ACCOUNT_NOT_ROLE = "5"; // 'The account has not been granted the role.'
    string public constant NOT_USED_AS_COLLATERAL = "6"; // The asset is not being used as collateral by the user
    string public constant NOT_ENOUGH_COLLATERAL_BORROW = "7"; // 'There is not enough collateral to borrow.'
    string public constant DEBT_EXCEEDS_COLLATERAL = "8"; // 'Debt exceeds collateral amount.'
    string public constant NOT_ENOUGH_COLLATERAL_BORROW_DEBT = "9"; // 'There is not enough collateral to cover the debt.'
    string public constant LTV_HEALTH_FACTOR_BELOW_1_LIQUIDATE = "10.5"; // 'LTV Health Factor is below 1 and should be liquidated.'
    string public constant HEALTH_FACTOR_BELOW_1_LIQUIDATE = "10"; // 'Liquidity Threshold Health Factor is below 1 and should be liquidated.'
    string public constant HEALTH_FACTOR_NOT_LOW_ENOUGH = "11"; // 'Health Factor not low enough, therefore account cannot be liquidated'
    string public constant INSUFFICIENT_BALANCE = "12"; // 'Insufficient balance to withdraw.'
    string public constant LTV_VALIDATION_FAILED = "13"; // Invalid Loan To Value Ratio
    string public constant SUPPLY_LIMIT_EXCEEDED = "14"; // Total Supply amount exceeds supply limit
    string public constant DEBT_LIMIT_EXCEEDED = "15"; // Total Debt amount exceeds debt limit
    string public constant HEALTH_FACTOR_TOO_LOW = "16"; // Health factor is too low for destination account for debt token transfers
    string public constant SAME_ACCOUNT_ID_NOT_ALLOWED = "17"; // Not allowed to transfer to same account ID
    string public constant DEPOSIT_NOT_ENABLED = "18"; // Depositing is not enabled
    string public constant BORROW_NOT_ENABLED = "19"; // Borrowing is not enabled
    string public constant CALLER_MUST_BE_PTOKEN = "20"; // Caller must be a pToken
    string public constant NO_SELECTORS = "21"; // LibDiamondCut: No selectors in facet to cut
    string public constant FACET_ADDRESS_NOT_ZERO = "22"; // LibDiamondCut: Add facet can't be address(0)
    string public constant FUNCTION_EXISTS = "23"; // "LibDiamondCut: Can't add function that already exists"
    string public constant REMOVE_EQUALS_ZERO = "24"; // "LibDiamondCut: Remove facet address must be address(0)"
    string public constant FUNCTION_DOESNT_EXIST_FACET = "25"; // "Function doesn't exist"
    string public constant FUNCTION_NOT_QUEUED = "26"; // "Function has not been queued"
    string public constant FUNCTION_TIMELOCKED = "27"; // "Function still timelocked"
    string public constant WRONG_ACTION = "28"; // "LibDiamondCut: Incorrect FacetCutAction"
    string public constant REVERT_ADDRESS = "29"; // "LibDiamondCut: Revert facet can't be address(0)"
    string public constant FACET_ADDRESS_DOESNT_MATCH = "30"; // "LibDiamondCut: Facet Address doesnt match for revert"
    string public constant REVERT_TIME_EXCEEDED = "31"; // "LibDiamondCut: Function revert time exceeded"
    string public constant REVERT_FUNCTION_SAME_ADDRESS = "32"; // "LibDiamondCut: Can't revert function with same address"
    string public constant FACET_HAS_NO_CODE = "33"; // "LibDiamondCut: New facet has no code"
    string public constant IMMUTABLE_FUNCTION = "34"; // "LibDiamondCut: Can't remove immutable function"
    string public constant INIT_HAS_NO_CODE = "35"; // "LibDiamondCut: _init address has no code"
    string public constant TIMELOCK_ZERO = "36"; // "Timelock value can't be zero"
    string public constant SAME_FUNCTION = "37"; // "LibDiamondCut: Can't replace function with same function"
    string public constant NOT_ENOUGH_ALLOWANCE = "38"; // "There is not enough allowance"
    string public constant NEW_BALANCE_INSUFFICIENT = "39"; // "The balance is not more than or equals to amount"
    string public constant TOO_MANY_DECIMALS = "40"; // "TOO_MANY_DECIMALS_ON_TOKEN"
    string public constant ADDRESS_NOT_ZERO = "41"; // "Address can't be zero"
    string public constant FUNCTION_DOESNT_EXIST = "42"; // "Diamond: Function does not exist"
    string public constant INSUFFICIENT_UNDERLYING_BALANCE = "43"; // "There is not enough underlying balance to work funds"
    string public constant SOURCE_STRATEGY_EXISTS = "44"; // The yield source has already been implemented by a different strategy
    string public constant BORROWING_MORE_THAN_AVAILABLE_LIQUIDITY = "45"; // Cant borrow more than total available liquidity
    string public constant NOT_LIQUIDATOR = "46"; // Liquidation call not made by the liquidator

}
