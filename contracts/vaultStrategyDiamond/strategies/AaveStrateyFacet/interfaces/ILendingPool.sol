// SPDX-License-Identifier: BUSL 1.1

pragma solidity >=0.6.0 <0.9.0;

interface ILendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}
