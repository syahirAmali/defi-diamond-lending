// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.17;

interface IWitnetOracle {
    function lastPrice() external view returns (int256);
}