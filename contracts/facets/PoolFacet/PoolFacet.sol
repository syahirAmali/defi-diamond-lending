// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {LibPool} from "./library/LibPool.sol";
import {DataTypes} from "../../libraries/types/DataTypes.sol";
import {PoolManagerStorage} from "../PoolManagerFacet/storage/PoolManagerStorage.sol";

contract PoolFacet {
    //***************************************************************//
    //  Pool Facet                                                   //
    //***************************************************************//

    //**Events*******************************************************//

    event Deposit(
        address indexed underlyingAsset,
        uint256 amount,
        address indexed from,
        address indexed to,
        bool depositedToVault
    );
    event Withdraw(
        address indexed underlyingAsset,
        uint256 amount,
        address indexed from,
        address indexed to
    );
    event Borrow(
        address indexed underlyingAsset,
        uint256 amount,
        address indexed borrower,
        address indexed onBehalfOf
    );
    event Repay(
        address indexed underlyingAsset,
        uint256 amount,
        address indexed borrower
    );
    event Liquidate(
        address indexed liquidator,
        address indexed liquidated,
        address collateralAsset,
        address debtAsset,
        uint256 debtCovered,
        uint256 collateralGained
    );
    event VaultYieldClaimed(
        address indexed user,
        address indexed to,
        address indexed token,
        uint256 rewards
    );
    event FundsWorked(
        address indexed caller,
        address indexed underlyingAsset,
        uint256 amount,
        uint256 vaultDepositFeesClaimed
    );
    event FundsWorkedWithdrew(
        address indexed caller,
        address indexed underlyingAsset,
        uint256 amount
    );
    event AssetUsedAsCollateralToggled(
        address _underlyingToken,
        address _user,
        bool useAsCollateral
    );

    //**Setters******************************************************//

    /// @notice deposits underlyingAsset, which will go into a lending pool and will recieve a PToken
    /// @param _underlyingAsset, underlyingAsset to be deposit
    /// @param _amount, amount of underlyingAsset to be deposited
    /// @param _to, receiver of the PToken
    function deposit(
        address _underlyingAsset,
        uint256 _amount,
        address _to,
        bool _depositToVault
    ) external {
        LibPool._deposit(_underlyingAsset, _amount, _to, _depositToVault);
        emit Deposit(
            _underlyingAsset,
            _amount,
            msg.sender,
            _to,
            _depositToVault
        );
    }

    /// @notice withdraws user's deposit from the lending pool
    /// @param _underlyingAsset, underlyingAsset to be withdrawn
    /// @param _amount, amount of underlyingAsset to be withdrawn
    /// @param _to, receiver of the underlyingAsset
    /// @notice an exact amount of the PToken will be burned at the same time
    function withdraw(
        address _underlyingAsset,
        uint256 _amount,
        address _to
    ) external {
        uint256 actualWithdrawAmount = LibPool._withdraw(
            _underlyingAsset,
            _amount,
            _to
        );
        emit Withdraw(_underlyingAsset, actualWithdrawAmount, msg.sender, _to);
    }

    /// @notice claim the interest gained from yields worked from the vault
    /// @param _underlyingAssets, Array of underlyingAsset to be claimed
    /// @param _to, receiver of the underlyingAsset
    function claimMultipleWorkedYields(
        address[] calldata _underlyingAssets,
        address _to
    ) external {
        uint256 totalAssets = _underlyingAssets.length;
        for (uint i; i < totalAssets; i++) {
            _autocompoundWorkedYield(_underlyingAssets[i], _to);
        }
    }

    /// @notice claim the interest gained from yields worked from the vault and redeposit it
    /// @param _underlyingAsset, underlyingAsset to be claimed
    /// @param _to, receiver of the underlyingAsset
    function claimWorkedYields(
        address _underlyingAsset,
        address _to
    ) external {
        _autocompoundWorkedYield(_underlyingAsset, _to);
    }

    function _autocompoundWorkedYield(
        address _underlyingAsset,
        address _to
    ) private {

        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        LibPool._updateRewards(asset);

        uint256 pendingRewards = LibPool._pendingRewards(
            asset,
            _underlyingAsset,
            msg.sender
        );

        if (pendingRewards > 0) {
            DataTypes.UserRewards storage userRewards = PoolManagerStorage
                .poolManagerStorage()
                .userRewards[_underlyingAsset][msg.sender];

            userRewards.rewardsOwed = 0;

            asset.rewardsClaimed += pendingRewards;
            LibPool._updateFundsWorked(asset, false, pendingRewards);

            emit VaultYieldClaimed(
                msg.sender,
                _to,
                _underlyingAsset,
                pendingRewards
            );

            // Normal Deposit stuff
            uint256 supplyIndex = LibPool._depositUpdateAndChecks(
                asset,
                pendingRewards
            );

            LibPool._mintPTokens(
                asset,
                userRewards,
                _underlyingAsset,
                _to,
                pendingRewards,
                supplyIndex
            );

            emit Deposit(
                _underlyingAsset,
                pendingRewards,
                msg.sender,
                _to,
                true
            );
        }

        emit VaultYieldClaimed(
            msg.sender,
            _to,
            _underlyingAsset,
            pendingRewards
        );
    }

    /// @notice Enables a user to borrow from the lending pool based on the borrowing power of their deposited collateral
    /// @param _underlyingAsset, underlying asset to borrow
    /// @param _amount, amount of underlying asset to borrow
    /// @param _onBehalfOf, Allows UserA to borrow `onBehalfOf` UserB, requires explicit approval from UserB to allow UserA to borrow
    function borrow(
        address _underlyingAsset,
        uint256 _amount,
        address _onBehalfOf
    ) external {
        LibPool._borrow(_underlyingAsset, _amount, _onBehalfOf);
        emit Borrow(_underlyingAsset, _amount, msg.sender, _onBehalfOf);
    }

    /// @notice repays borrowed debt
    /// @param _underlyingAsset, repays this underlyingAsset
    /// @param _amount, amount of debt to repay
    /// @param _to, reapays this user's debt
    function repay(
        address _underlyingAsset,
        uint256 _amount,
        address _to
    ) external {
        uint256 actualRepayAmount = LibPool._repay(
            _underlyingAsset,
            _amount,
            _to
        );
        emit Repay(_underlyingAsset, actualRepayAmount, _to);
    }

    /// @notice Toggles the asset to be used as collateral by the user
    /// @param _underlyingAsset, underlying asset to toggle
    /// @param _useAsCollateral, true to be used as collateral false to disable use as collateral
    function setUserUseAssetAsCollateral(
        address _underlyingAsset,
        bool _useAsCollateral
    ) external {
        LibPool._setUserUseAssetAsCollateral(
            _underlyingAsset,
            _useAsCollateral
        );
    }

    /**
     * @dev Called when pTokens are transferred,
     * validates it has proper health factor after transfer
     */
    function finalizeTransfer(
        address _underlyingAsset,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _fromBalanceBefore,
        uint256 _toBalanceBefore
    ) public {
        LibPool._finalizeTransfer(
            _underlyingAsset,
            _from,
            _to,
            _amount,
            _fromBalanceBefore,
            _toBalanceBefore
        );
    }

    /// @notice Liquidiate a user's borrow posisition once a user's health factor drop belows 1
    /// @notice can only be called by the approved liquidator
    function liquidate(
        address _user,
        address _underlyingCollateralAsset,
        address _underlyingDebtAsset,
        uint256 _debtToCover,
        bool _allowSwaps,
        bytes calldata _params
    ) external {
        (uint256 actualCollateralAmount, uint256 actualDebtAmount) = LibPool
            ._liquidate(
                LibPool.LiquidateParams({
                    user: _user,
                    underlyingCollateralAsset: _underlyingCollateralAsset,
                    underlyingDebtAsset: _underlyingDebtAsset,
                    debtToCover: _debtToCover,
                    allowSwaps: _allowSwaps,
                    params: _params
                })
            );
        emit Liquidate(
            msg.sender,
            _user,
            _underlyingCollateralAsset,
            _underlyingDebtAsset,
            actualDebtAmount,
            actualCollateralAmount
        );
    }

    function version() external pure returns (uint8) {
        return LibPool.version;
    }
}
