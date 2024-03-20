// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Pinjam Interface
interface IPinjam {
    /// @notice Deposits an underlying asset in exchange for pTokens
    /// @param _underlyingAsset, underlying asset to deposit
    function deposit(
        address _underlyingAsset,
        uint256 _amount,
        address _to,
        bool _depositToVault
    ) external;

    /// @notice Withdraws _underlying asset in exchange for PTokens
    /// @param _underlyingAsset, underlying asset to withdraw
    function withdraw(
        address _underlyingAsset,
        uint256 _amount,
        address _to
    ) external;

    /// @notice Claims worked yield and reciev pTokens based on the underlying asset
    /// @param _underlyingAsset, underlying asset to claim
    function claimWorkedYields(
        address _underlyingAsset,
        address _to
    ) external;

    /// @notice Borrows from the lending pool based on collateral amoun from deposit
    /// @param _underlyingAsset, underlying asset to borrow
    /// @param _onBehalfOf, borrows on behalf of a user based on the approval given
    function borrow(
        address _underlyingAsset,
        uint256 _amount,
        address _onBehalfOf
    ) external;

    /// @notice Repays a borrowed amount from the lending pool
    /// @param _underlyingAsset, underlying asset to repay
    function repay(
        address _underlyingAsset,
        uint256 _amount,
        address _to
    ) external;
    
    /// @notice Gets the pToken of an underlying address
    /// @param _underlyingAsset, underlying asset to repay
    function getPToken(
        address _underlyingAsset
    ) external view returns (address);
}
