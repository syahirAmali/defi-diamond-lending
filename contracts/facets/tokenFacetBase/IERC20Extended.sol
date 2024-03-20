// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

/**
 * @title Partial ERC20 interface needed by extended functions
 */
interface IERC20Extended {
    function increaseAllowance(address spender, uint256 amount) external returns (bool);
    function decreaseAllowance(address spender, uint256 amount) external returns (bool);
}
