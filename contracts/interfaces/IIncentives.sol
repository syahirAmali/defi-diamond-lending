// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Incentives Interface
interface IIncentives {
    /// @notice Claims Pinkav incentives
    /// @param _tokens, pTokens to claim incentives for
    /// @param _lock, whether to lock the claimed incentives, true for lock, false for vest
    function claim(
        address _user,
        address[] calldata _tokens,
        bool _lock
    ) external;
}
