// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PTokenFacet} from "../../PTokenFacet/PTokenFacet.sol";
import {DebtTokenFacet} from "../../DebtTokenFacet/DebtTokenFacet.sol";
import {WitnetOracleStorage} from "../../OracleFacet/storage/WitnetOracleStorage.sol";
import {DataTypes} from "../../../libraries/types/DataTypes.sol";
import {PoolManagerStorage} from "../../PoolManagerFacet/storage/PoolManagerStorage.sol";
import {AddressRegistryStorage} from "../../AddressRegistryFacet/storage/AddressRegistryStorage.sol";
import {Errors} from "../../../libraries/helpers/Errors.sol";
import {WadRayMath} from "../../../libraries/math/WadRayMath.sol";
import {SafeCast} from "../../../libraries/math/SafeCast.sol";
import {PercentageMath} from "../../../libraries/math/PercentageMath.sol";
import {AssetConfiguration} from "../../../libraries/configuration/AssetConfiguration.sol";
import {UserConfiguration} from "../../../libraries/configuration/UserConfiguration.sol";
import {LibDiamond} from "../../../libraries/LibDiamond.sol";
import {LibReserveLogic} from "../../../libraries/LibReserveLogic.sol";

interface ITokenManagerFacet {
    function getVault() external returns (address);

    function workFunds(uint256 _amount) external;

    function withdrawFunds(uint256 _amount) external;

    function getBalance() external view returns (uint256);
}

interface ILiquidator {
    function handleSwap(
        uint256 actualCollateralAmount,
        uint256 actualDebtAmount,
        bytes calldata params
    ) external;
}

library LibPool {
    using WadRayMath for uint256;
    using SafeCast for uint256;
    using PercentageMath for uint256;
    using AssetConfiguration for DataTypes.AssetConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    //**Constants****************************************************//

    uint8 public constant version = 1;
    uint256 private constant REWARDS_PRECISION = 1e27;

    //**Events*******************************************************//

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
    event AssetIsBorrowedToggled(
        address _underlyingToken,
        address _user,
        bool isBorrowed
    );

    //**Setters******************************************************//

    function _workFunds(
        address _underlyingAsset,
        uint256 _amount,
        bool claimVaultFees
    ) internal returns (uint256 vaultDepositFees) {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        uint256 amountToUpdate = _amount;

        if (claimVaultFees) {
            vaultDepositFees = asset.vaultDepositFees;
            asset.vaultDepositFees = 0;
            asset.rewardsClaimed += vaultDepositFees;
            amountToUpdate += vaultDepositFees;
        }

        _updateFundsWorked(asset, false, amountToUpdate);
        ITokenManagerFacet(asset.pToken).workFunds(_amount);

        emit FundsWorked(
            msg.sender,
            _underlyingAsset,
            asset.amountWorked,
            vaultDepositFees
        );
    }

    function _assetWithdrawAllWorkedFunds(address _underlyingAsset) internal {
        _withdrawAllWorkedFunds(
            PoolManagerStorage.poolManagerStorage().supportedAssets[
                _underlyingAsset
            ],
            _underlyingAsset
        );
    }

    function _withdrawAllWorkedFunds(
        DataTypes.SupportedAsset storage _asset,
        address _underlyingAsset
    ) internal {
        _withdrawWorkedFunds(_asset, _underlyingAsset, _asset.amountWorked);
    }

    function _withdrawWorkedFunds(
        DataTypes.SupportedAsset storage _asset,
        address _underlyingAsset,
        uint256 _withdrawAmount
    ) internal {
        _updateFundsWorked(_asset, true, _withdrawAmount);
        ITokenManagerFacet(_asset.pToken).withdrawFunds(_withdrawAmount);

        emit FundsWorkedWithdrew(msg.sender, _underlyingAsset, _withdrawAmount);
    }

    function _updateUserRewardsOwed(
        DataTypes.UserRewards storage userRewards,
        uint256 userPBalance,
        uint256 accRewardPerShare
    ) internal {
        uint256 totalRewards = (userPBalance * accRewardPerShare) /
            REWARDS_PRECISION;
        uint256 rewardDebt = userRewards.rewardDebt;

        if (rewardDebt > totalRewards) {
            return;
        }

        uint256 pending = totalRewards - rewardDebt;
        if (pending > 0) {
            userRewards.rewardsOwed += pending;
        }
    }

    function _depositUpdateAndChecks(
        DataTypes.SupportedAsset storage _asset,
        uint256 _amount
    ) internal returns (uint256 supplyIndex_) {
        _updateReserves(_asset, _amount, 0, 0, 0);

        supplyIndex_ = LibReserveLogic._getNormalizedSupplyIndex(_asset);
        uint256 supplyLimit = _asset.config.getSupplyLimit();
        if (supplyLimit > 0) {
            require(
                supplyLimit * (10 ** _asset.config.getDecimals()) >=
                    _scaleUpAmount(_asset.totalLiquidity, supplyIndex_),
                Errors.SUPPLY_LIMIT_EXCEEDED
            );
        }
    }

    function _updateUserVaultRewardDebt(
        DataTypes.SupportedAsset storage _asset,
        DataTypes.UserRewards storage _userRewards,
        address _user
    ) internal {
        // Updating user reward debt to ensure they do not steal existing users vault rewards
        _userRewards.rewardDebt =
            (IERC20(_asset.pToken).balanceOf(_user) *
                _asset.accRewardPerShare) /
            REWARDS_PRECISION;
    }

    function _mintPTokens(
        DataTypes.SupportedAsset storage _asset,
        DataTypes.UserRewards storage _userRewards,
        address _underlyingAsset,
        address _to,
        uint256 _amount,
        uint256 _supplyIndex
    ) internal {
        require(_asset.config.getDepositEnabled(), Errors.DEPOSIT_NOT_ENABLED);

        bool isFirstDeposit = PTokenFacet(_asset.pToken).mint(
            _to,
            _amount,
            _supplyIndex
        );
        if (isFirstDeposit) {
            PoolManagerStorage
                .poolManagerStorage()
                .userConfig[_to]
                .setUsingAsCollateral(_asset.config.getReserveId(), true);
            emit AssetUsedAsCollateralToggled(_underlyingAsset, _to, true);
        }

        _updateUserVaultRewardDebt(_asset, _userRewards, _to);
        _updateInterestRates(_asset);
    }

    function _deposit(
        address _underlyingAsset,
        uint256 _amount,
        address _to,
        bool _depositToVault
    ) internal returns (uint256) {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        require(asset.config.getDepositEnabled(), Errors.DEPOSIT_NOT_ENABLED);

        _updateRewards(asset);

        uint256 userPBalance = IERC20(asset.pToken).balanceOf(_to);
        DataTypes.UserRewards storage userRewards = PoolManagerStorage
            .poolManagerStorage()
            .userRewards[_underlyingAsset][_to];

        if (userPBalance > 0) {
            _updateUserRewardsOwed(
                userRewards,
                userPBalance,
                asset.accRewardPerShare
            );
        }

        uint256 supplyIndex = _depositUpdateAndChecks(asset, _amount);

        address pToken = asset.pToken;

        IERC20(_underlyingAsset).transferFrom(
            msg.sender,
            address(pToken),
            _amount
        );

        uint256 depositToVaultFees;

        if (asset.depositToVaultStatus) {
            if (_depositToVault) {
                uint256 maxCapitalEfficiencyBp = asset
                    .config
                    .getMaxCapitalEfficiency();
                uint256 underlyingBalToWork = IERC20(_underlyingAsset)
                    .balanceOf(pToken);

                require(
                    underlyingBalToWork > 0,
                    Errors.INSUFFICIENT_UNDERLYING_BALANCE
                );

                if (maxCapitalEfficiencyBp > 0) {
                    uint256 totalSupply = asset.totalLiquidity.rayMul(
                        asset.supplyIndex
                    );
                    uint256 minReserveAmount = totalSupply.percentMul(
                        PercentageMath.PERCENTAGE_FACTOR -
                            maxCapitalEfficiencyBp
                    );

                    uint256 maxCapitalToWork = totalSupply - minReserveAmount;

                    uint256 newTotalProductiveCapital = underlyingBalToWork +
                        asset.amountWorked +
                        asset.totalDebt.rayMul(asset.borrowIndex);
                    if (newTotalProductiveCapital > maxCapitalToWork) {
                        underlyingBalToWork -= minReserveAmount;
                    }
                }

                if (underlyingBalToWork > 0) {
                    depositToVaultFees = _workFunds(
                        _underlyingAsset,
                        underlyingBalToWork,
                        true
                    );
                }
            }
        }

        _amount += depositToVaultFees;
        _mintPTokens(
            asset,
            userRewards,
            _underlyingAsset,
            _to,
            _amount,
            supplyIndex
        );

        return _amount;
    }

    function _withdraw(
        address _underlyingAsset,
        uint256 _amountToWithdraw,
        address _to
    ) internal returns (uint256) {
        address WETH_GATEWAY = AddressRegistryStorage
            .registryStorage()
            .wethGateway;

        require(msg.sender != WETH_GATEWAY, "WETH_GATEWAY_NOT_ALLOWED");
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        address pToken = asset.pToken;
        uint256 userBalance = IERC20(pToken).balanceOf(msg.sender);

        require(userBalance > 0, Errors.INSUFFICIENT_BALANCE);

        if (_amountToWithdraw > userBalance) {
            _amountToWithdraw = userBalance;
        }

        require(
            _balanceDecreaseAllowed(
                asset,
                _underlyingAsset,
                msg.sender,
                _amountToWithdraw
            ),
            Errors.HEALTH_FACTOR_BELOW_1_LIQUIDATE
        );

        _updateReserves(asset, 0, _amountToWithdraw, 0, 0);

        // Vault Rewards
        DataTypes.UserRewards storage userRewards = PoolManagerStorage
            .poolManagerStorage()
            .userRewards[_underlyingAsset][msg.sender];
        _updateRewards(asset);
        _updateUserRewardsOwed(
            userRewards,
            IERC20(pToken).balanceOf(msg.sender),
            asset.accRewardPerShare
        );

        // Normal Withdraw stuff
        _updateInterestRates(asset);

        _requiredToWithdrawFromVault(
            asset,
            _underlyingAsset,
            _amountToWithdraw
        );

        PTokenFacet(pToken).burn(
            msg.sender,
            _to,
            _amountToWithdraw,
            LibReserveLogic._getNormalizedSupplyIndex(asset)
        );

        if (_amountToWithdraw == userBalance) {
            PoolManagerStorage
                .poolManagerStorage()
                .userConfig[msg.sender]
                .setUsingAsCollateral(asset.config.getReserveId(), false);

            emit AssetUsedAsCollateralToggled(
                _underlyingAsset,
                msg.sender,
                false
            );
        }

        // Updating user reward debt to ensure they do not steal other users vault rewards
        _updateUserVaultRewardDebt(asset, userRewards, _to);

        return _amountToWithdraw;
    }

    /// @notice Update reward variables of the given pool to be up-to-date.
    function _updateRewards(DataTypes.SupportedAsset storage _asset) internal {
        uint256 pSupply = IERC20(_asset.pToken).totalSupply();
        if (pSupply == 0) {
            return;
        }

        uint256 currRewards = _currVaultRewards(_asset);
        uint256 tokenTotalReceived = currRewards + _asset.rewardsClaimed;

        if (_asset.rewardsClaimed > _asset.accRewards) {
            _asset.accRewards = _asset.rewardsClaimed;
        }

        if (_asset.accRewards > tokenTotalReceived) return;
        uint256 newRewards = tokenTotalReceived - _asset.accRewards;
        if (newRewards != 0) {
            uint256 accruedFees = newRewards.percentMul(
                _asset.config.getFarmingReserveFactor()
            );

            // Vault Deposit fee accrued is 5% of total accrued fees
            uint256 vaultDepositFee = accruedFees.percentMul(
                PoolManagerStorage.VAULT_DEPOSIT_FEES
            );

            _asset.vaultDepositFees += vaultDepositFee;
            _asset.accRewards += newRewards;
            newRewards = newRewards - accruedFees;

            uint256 taxRewards = newRewards.percentMul(1000);
            newRewards = newRewards - taxRewards;

            _asset.accRewardPerShare =
                _asset.accRewardPerShare +
                (((newRewards) * REWARDS_PRECISION) / pSupply);

            // Handling farm fees to treasury
            uint256 farmFees = accruedFees - vaultDepositFee;
            _asset.rewardsClaimed += farmFees;
            _asset.amountWorked += farmFees;
            PTokenFacet(_asset.pToken).mintToTreasury(
                farmFees,
                LibReserveLogic._getNormalizedSupplyIndex(_asset)
            );
        }
    }

    function _borrow(
        address _underlyingAsset,
        uint256 _borrowAmount,
        address _onBehalfOf
    ) internal {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        require(asset.config.getBorrowEnabled(), Errors.BORROW_NOT_ENABLED);

        _updateReserves(asset, 0, 0, _borrowAmount, 0);
        require(
            asset.totalDebt <= asset.totalLiquidity,
            Errors.BORROWING_MORE_THAN_AVAILABLE_LIQUIDITY
        );
        address pToken = asset.pToken;
        address debtToken = asset.debtToken;

        uint256 _index = LibReserveLogic._getNormalizedBorrowIndex(asset);

        uint256 debtLimit = asset.config.getDebtLimit();

        if (debtLimit > 0) {
            require(
                debtLimit * (10 ** asset.config.getDecimals()) >=
                    _scaleUpAmount(asset.totalDebt, _index),
                Errors.DEBT_LIMIT_EXCEEDED
            );
        }

        if (msg.sender != _onBehalfOf) {
            uint256 allowance = DebtTokenFacet(debtToken).borrowAllowance(
                _onBehalfOf,
                msg.sender
            );

            require(allowance >= _borrowAmount, Errors.NOT_ENOUGH_ALLOWANCE);

            DebtTokenFacet(debtToken).decreaseBorrowAllowanceDiamond(
                _onBehalfOf,
                msg.sender,
                _borrowAmount
            );
        }

        bool isFirstBorrowing = DebtTokenFacet(debtToken).mint(
            _onBehalfOf,
            _borrowAmount,
            _index
        );

        if (isFirstBorrowing) {
            PoolManagerStorage
                .poolManagerStorage()
                .userConfig[_onBehalfOf]
                .setBorrowing(asset.config.getReserveId(), true);
            emit AssetIsBorrowedToggled(_underlyingAsset, _onBehalfOf, true);
        }

        _updateInterestRates(asset);

        {
            (
                uint256 liqThreshHealthFactor,
                uint256 totalCollateralInBaseCurrency,
                uint256 totalDebtInBaseCurrency,
                uint256 avgLtv,

            ) = _getUserData(_onBehalfOf);

            uint256 ltvHealthFactor = calculateHealthFactorFromBalances(
                totalCollateralInBaseCurrency,
                totalDebtInBaseCurrency,
                avgLtv
            );

            require(
                ltvHealthFactor >=
                    PoolManagerStorage.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
                Errors.LTV_HEALTH_FACTOR_BELOW_1_LIQUIDATE
            );

            require(
                liqThreshHealthFactor >=
                    PoolManagerStorage.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
                Errors.HEALTH_FACTOR_BELOW_1_LIQUIDATE
            );

            require(avgLtv != 0, Errors.LTV_VALIDATION_FAILED);
        }

        _requiredToWithdrawFromVault(asset, _underlyingAsset, _borrowAmount);

        PTokenFacet(pToken).transferUnderlyingTo(msg.sender, _borrowAmount);
    }

    function _repay(
        address _underlyingAsset,
        uint256 _amount,
        address _to
    ) internal returns (uint256) {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        uint256 maxDebt = IERC20(asset.debtToken).balanceOf(_to);

        if (_amount > maxDebt) {
            _amount = maxDebt;
        }

        _updateReserves(asset, 0, 0, 0, _amount);
        _updateInterestRates(asset);

        DebtTokenFacet(asset.debtToken).burn(
            _to,
            _amount,
            LibReserveLogic._getNormalizedBorrowIndex(asset)
        );

        if (maxDebt - _amount == 0) {
            PoolManagerStorage
                .poolManagerStorage()
                .userConfig[_to]
                .setBorrowing(asset.config.getReserveId(), false);
            emit AssetIsBorrowedToggled(_underlyingAsset, _to, false);
        }

        IERC20(_underlyingAsset).transferFrom(
            msg.sender,
            asset.pToken,
            _amount
        );

        return _amount;
    }

    struct LiquidateParams {
        address user;
        address underlyingCollateralAsset;
        address underlyingDebtAsset;
        uint256 debtToCover;
        bool allowSwaps;
        bytes params;
    }

    function _liquidate(
        LiquidateParams memory _params
    )
        internal
        returns (uint256 actualCollateralAmount, uint256 actualDebtAmount)
    {
        require(
            msg.sender == PoolManagerStorage.poolManagerStorage().liquidator,
            Errors.NOT_LIQUIDATOR
        );

        DataTypes.SupportedAsset storage debtAsset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_params.underlyingDebtAsset];
        DataTypes.SupportedAsset storage pAsset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_params.underlyingCollateralAsset];

        require(
            PoolManagerStorage
                .poolManagerStorage()
                .userConfig[_params.user]
                .isUsingAsCollateral(pAsset.config.getReserveId()),
            Errors.NOT_USED_AS_COLLATERAL
        );

        (uint256 healthFactor, , , , ) = _getUserData(_params.user);
        require(
            healthFactor <
                PoolManagerStorage.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            Errors.HEALTH_FACTOR_NOT_LOW_ENOUGH
        );

        uint256 _borrowIndex = LibReserveLogic._getNormalizedBorrowIndex(
            debtAsset
        );
        uint256 _supplyIndex = LibReserveLogic._getNormalizedSupplyIndex(
            pAsset
        );

        uint256 userCollateralBalance = IERC20(pAsset.pToken).balanceOf(
            _params.user
        );
        uint256 userDebtBalance = IERC20(debtAsset.debtToken).balanceOf(
            _params.user
        );

        _params.debtToCover = _calculateDebt(
            userDebtBalance,
            _params.debtToCover,
            healthFactor
        );
        (actualCollateralAmount, actualDebtAmount) = _calcRepaymentAmount(
            _params.underlyingCollateralAsset,
            _params.underlyingDebtAsset,
            _params.debtToCover,
            userCollateralBalance,
            pAsset.config.getDecimals(),
            debtAsset.config.getDecimals(),
            pAsset.config.getLiquidationBonus()
        );

        uint256 userPBalance = PTokenFacet(pAsset.pToken).balanceOf(
            _params.user
        );
        if (actualCollateralAmount > userPBalance) {
            actualCollateralAmount = userPBalance;
        }

        _updateReserves(debtAsset, 0, 0, 0, actualDebtAmount);
        _updateReserves(pAsset, 0, actualCollateralAmount, 0, 0);

        _updateInterestRates(debtAsset);
        _updateInterestRates(pAsset);
        {
            address user = _params.user;
            DebtTokenFacet(debtAsset.debtToken).burn(
                user,
                actualDebtAmount,
                _borrowIndex
            );

            _requiredToWithdrawFromVault(
                pAsset,
                _params.underlyingCollateralAsset,
                actualCollateralAmount
            );

            PTokenFacet(pAsset.pToken).burn(
                user,
                msg.sender,
                actualCollateralAmount,
                _supplyIndex
            );

            if (actualCollateralAmount == userPBalance) {
                PoolManagerStorage
                    .poolManagerStorage()
                    .userConfig[user]
                    .setUsingAsCollateral(pAsset.config.getReserveId(), false);
                emit AssetUsedAsCollateralToggled(
                    _params.underlyingCollateralAsset,
                    user,
                    false
                );
            }
        }
        {
            if (_params.allowSwaps) {
                ILiquidator(msg.sender).handleSwap(
                    actualCollateralAmount,
                    actualDebtAmount,
                    _params.params
                );
            }

            IERC20(_params.underlyingDebtAsset).transferFrom(
                msg.sender,
                address(debtAsset.pToken),
                actualDebtAmount
            );
        }
    }

    function _setUserUseAssetAsCollateral(
        address _underlyingAsset,
        bool useAsCollateral
    ) internal {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];
        uint256 underlyingBalance = IERC20(asset.pToken).balanceOf(msg.sender);
        require(underlyingBalance > 0, Errors.INSUFFICIENT_BALANCE);

        require(
            useAsCollateral ||
                _balanceDecreaseAllowed(
                    asset,
                    _underlyingAsset,
                    msg.sender,
                    underlyingBalance
                ),
            Errors.HEALTH_FACTOR_BELOW_1_LIQUIDATE
        );

        PoolManagerStorage
            .poolManagerStorage()
            .userConfig[msg.sender]
            .setUsingAsCollateral(asset.config.getReserveId(), useAsCollateral);

        emit AssetUsedAsCollateralToggled(
            _underlyingAsset,
            msg.sender,
            useAsCollateral
        );
    }

    /**
     * @dev Validates and finalizes a pToken transfer
     * - Only callable by the underlying pToken of the `asset`
     * @param _underlyingAsset The address of the underlying asset of the pToken
     * @param _from The user from which the pTokens are transferred
     * @param _to The user receiving the pTokens
     * @param _amount The amount being transferred/withdrawn
     * @param _fromBalanceBefore The pToken balance of the `from` user before the transfer
     * @param _toBalanceBefore The pToken balance of the `to` user before the transfer
     */
    function _finalizeTransfer(
        address _underlyingAsset,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _fromBalanceBefore,
        uint256 _toBalanceBefore
    ) internal {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        require(msg.sender == asset.pToken, Errors.CALLER_MUST_BE_PTOKEN);

        (
            uint256 healthFactor,
            ,
            uint256 totalDebtInBaseCurrency,
            ,

        ) = _getUserData(_from);
        if (totalDebtInBaseCurrency > 0) {
            // Minimum health factor should be 1.2 for transfer to be allowed
            require(healthFactor > 1.2 ether, Errors.HEALTH_FACTOR_TOO_LOW);
        }

        if (_from != _to) {
            if (_fromBalanceBefore - _amount == 0) {
                PoolManagerStorage
                    .poolManagerStorage()
                    .userConfig[_from]
                    .setUsingAsCollateral(asset.config.getReserveId(), false);
                emit AssetUsedAsCollateralToggled(
                    _underlyingAsset,
                    _from,
                    false
                );
            }

            if (_toBalanceBefore == 0 && _amount != 0) {
                PoolManagerStorage
                    .poolManagerStorage()
                    .userConfig[_to]
                    .setUsingAsCollateral(asset.config.getReserveId(), true);
                emit AssetUsedAsCollateralToggled(_underlyingAsset, _to, true);
            }

            // Vault Rewards
            DataTypes.UserRewards storage userRewardsFrom = PoolManagerStorage
                .poolManagerStorage()
                .userRewards[_underlyingAsset][_from];

            DataTypes.UserRewards storage userRewardsTo = PoolManagerStorage
                .poolManagerStorage()
                .userRewards[_underlyingAsset][_to];

            _updateRewards(asset);

            _updateUserRewardsOwed(
                userRewardsFrom,
                IERC20(asset.pToken).balanceOf(_from) + _amount,
                asset.accRewardPerShare
            );

            if (IERC20(asset.pToken).balanceOf(_to) - _amount > 0) {
                _updateUserRewardsOwed(
                    userRewardsTo,
                    IERC20(asset.pToken).balanceOf(_to) - _amount,
                    asset.accRewardPerShare
                );
            }

            _updateUserVaultRewardDebt(asset, userRewardsFrom, _from);
            _updateUserVaultRewardDebt(asset, userRewardsTo, _to);
        }
    }

    function _updateFundsWorked(
        DataTypes.SupportedAsset storage asset,
        bool _isWithdrawal,
        uint256 _amount
    ) internal {
        uint256 amountWorked = asset.amountWorked;

        if (!_isWithdrawal) {
            asset.amountWorked += _amount;
        } else {
            if (_amount > amountWorked) {
                _amount = amountWorked;
            }

            asset.amountWorked -= _amount;
        }
    }

    function _updateReserves(
        DataTypes.SupportedAsset storage _asset,
        uint256 _liquidityAdded,
        uint256 _liquidityRemove,
        uint256 _debtTaken,
        uint256 _debtRepaid
    ) internal {
        uint256 oldBorrowIndex = _asset.borrowIndex;

        uint256 supplyIndex = LibReserveLogic
            ._calcLinearInterest(
                _asset.currentSupplyRate,
                _asset.lastUpdateTimestamp
            )
            .rayMul(_asset.supplyIndex);
        uint256 newBorrowIndex = LibReserveLogic
            ._calcCompoundedInterest(
                _asset.currentBorrowRate,
                _asset.lastUpdateTimestamp
            )
            .rayMul(_asset.borrowIndex);
        // Accrue fees to treasury
        _accrueToTreasury(_asset, supplyIndex, oldBorrowIndex, newBorrowIndex);

        // Should not be unchecked as _liquidityAdded, _liquidityRemove, _debtTaken & _debtRepaid
        // can be external inputs with no sanity check
        _asset.totalLiquidity += _liquidityAdded.rayDiv(supplyIndex);
        uint256 liqToRemove = _liquidityRemove.rayDiv(supplyIndex);
        if (_asset.totalLiquidity >= liqToRemove) {
            _asset.totalLiquidity -= liqToRemove;
        } else {
            _asset.totalLiquidity = 0;
        }
        _asset.supplyIndex = supplyIndex.toUint128();

        _asset.totalDebt += _debtTaken.rayDiv(newBorrowIndex);
        uint256 debtToRemove = _debtRepaid.rayDiv(newBorrowIndex);
        if (_asset.totalDebt >= debtToRemove) {
            _asset.totalDebt -= debtToRemove;
        } else {
            _asset.totalDebt = 0;
        }
        _asset.borrowIndex = newBorrowIndex.toUint128();
        _asset.lastUpdateTimestamp = uint40(block.timestamp);
    }

    function _accrueToTreasury(
        DataTypes.SupportedAsset storage asset,
        uint256 currSupplyIndex,
        uint256 oldBorrowIndex,
        uint256 newBorrowIndex
    ) internal {
        uint256 prevTotalDebt = _scaleUpAmount(asset.totalDebt, oldBorrowIndex);
        uint256 currTotalDebt = _scaleUpAmount(asset.totalDebt, newBorrowIndex);
        uint256 totalDebtAccrued = currTotalDebt - prevTotalDebt;
        if (totalDebtAccrued == 0) return;

        PTokenFacet(asset.pToken).mintToTreasury(
            totalDebtAccrued.percentMul(asset.config.getBorrowReserveFactor()),
            currSupplyIndex
        );
    }

    function _updateInterestRates(
        DataTypes.SupportedAsset storage _asset
    ) internal {
        (uint256 supplyRate, uint256 borrowRate) = _calcInterestRates(
            CalculateInterestRateParams({
                totalDebt: _asset.totalDebt,
                totalLiquidity: _asset.totalLiquidity,
                variableSlope1: _asset.variableSlope1,
                variableSlope2: _asset.variableSlope2,
                optimalUtilizationRate: _asset.optimalUtilizationRate,
                borrowReserveRate: _asset.config.getBorrowReserveFactor()
            })
        );

        _asset.currentSupplyRate = supplyRate.toUint128();
        _asset.currentBorrowRate = borrowRate.toUint128();
    }

    /**
     * @dev checks if there is sufficient underlying balance in pToken, if not, withdraw from vault
     */
    function _requiredToWithdrawFromVault(
        DataTypes.SupportedAsset storage asset,
        address _underlyingAsset,
        uint256 _amountRequired
    ) internal {
        uint256 balanceOfUnderlyingInPToken = IERC20(_underlyingAsset)
            .balanceOf(asset.pToken);

        if (
            balanceOfUnderlyingInPToken >= _amountRequired ||
            ITokenManagerFacet(asset.pToken).getVault() == address(0)
        ) return;

        _withdrawWorkedFunds(
            asset,
            _underlyingAsset,
            _amountRequired - balanceOfUnderlyingInPToken // Exact amount to withdraw to meet withdrawal demand
        );
    }

    //**Getters******************************************************//

    function _balanceDecreaseAllowed(
        DataTypes.SupportedAsset storage _asset,
        address _underlyingAddress,
        address _user,
        uint256 _amount
    ) internal view returns (bool) {
        uint256 liquidationThreshold = _asset.config.getLiquidationThreshold();
        if (liquidationThreshold == 0) return true;

        (
            ,
            uint256 totalCollateralInBaseCurrency,
            uint256 totalDebtInBaseCurrency,
            ,
            uint256 avgLiquidationThreshold
        ) = _getUserData(_user);

        if (totalDebtInBaseCurrency == 0) return true;
        // Assets are only added by owner, therefore no token decimals should be infinitely high
        uint256 amountToDecreaseInBaseCurrency = (WitnetOracleStorage
            ._getAssetPrice(_underlyingAddress) * _amount) /
            10 ** _asset.config.getDecimals();

        uint256 collateralBalanceAfterDecrease = totalCollateralInBaseCurrency -
            amountToDecreaseInBaseCurrency;

        uint256 liquidationThresholdAfterDecrease = ((totalCollateralInBaseCurrency *
                avgLiquidationThreshold) -
                (amountToDecreaseInBaseCurrency * liquidationThreshold)) /
                collateralBalanceAfterDecrease;

        return
            calculateHealthFactorFromBalances(
                collateralBalanceAfterDecrease,
                totalDebtInBaseCurrency,
                liquidationThresholdAfterDecrease
            ) > PoolManagerStorage.HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    }

    function _pendingRewards(
        address _underlyingAsset,
        address _user
    ) internal view returns (uint256) {
        return
            _pendingRewards(
                PoolManagerStorage.poolManagerStorage().supportedAssets[
                    _underlyingAsset
                ],
                _underlyingAsset,
                _user
            );
    }

    /// @notice View function to see pending Vault Rewards on frontend.
    function _pendingRewards(
        DataTypes.SupportedAsset storage _asset,
        address _underlyingAsset,
        address _user
    ) internal view returns (uint256) {

        DataTypes.UserRewards storage user = PoolManagerStorage
            .poolManagerStorage()
            .userRewards[_underlyingAsset][_user];

        uint256 accRewardPerShare = _asset.accRewardPerShare;
        uint256 tokenTotalReceived = _currVaultRewards(_asset) +
            _asset.rewardsClaimed;
        uint256 accRewards = _asset.accRewards;
        if (_asset.rewardsClaimed > _asset.accRewards) {
            accRewards = _asset.rewardsClaimed;
        }

        uint256 newRewards;
        if (tokenTotalReceived > accRewards) {
            newRewards = tokenTotalReceived - accRewards;
        }

        uint256 pSupply = IERC20(_asset.pToken).totalSupply();
        if (newRewards != 0 && pSupply != 0) {
            uint256 feesAccrued = newRewards
                .percentMul(_asset.config.getFarmingReserveFactor())
                .toUint128();

            newRewards = newRewards - feesAccrued;
            uint256 taxRewards = newRewards.percentMul(1000);
            newRewards = newRewards - taxRewards;
            
            accRewardPerShare =
                accRewardPerShare +
                ((newRewards * REWARDS_PRECISION) / pSupply);
        }

        uint256 userDebt = user.rewardDebt;
        uint256 userRewards = ((IERC20(_asset.pToken).balanceOf(_user) *
            accRewardPerShare) / REWARDS_PRECISION) + user.rewardsOwed;

        if (userDebt > userRewards) return 0;
        return userRewards - userDebt;
    }

    function _currVaultRewards(
        DataTypes.SupportedAsset storage asset
    ) internal view returns (uint256 totalRewards) {
        uint256 vaultBal = ITokenManagerFacet(asset.pToken).getBalance();

        if (vaultBal == 0 || asset.amountWorked > vaultBal) return totalRewards;
        // Should not underflow as all checks are done above
        unchecked {
            totalRewards = vaultBal - asset.amountWorked;
        }
    }

    function _calcRepaymentAmount(
        address _underlyingCollateralAsset,
        address _underlyingDebtAsset,
        uint256 _debtToCover,
        uint256 _userCollateralBalance,
        uint256 _pTokenDecimals,
        uint256 _debtTokenDecimals,
        uint256 liquidationBonus
    )
        internal
        view
        returns (uint256 actualCollateralAmount, uint256 actualDebtAmount)
    {
        uint256 collateralPrice = WitnetOracleStorage._getAssetPrice(
            _underlyingCollateralAsset
        );

        uint256 debtAssetPrice = WitnetOracleStorage._getAssetPrice(
            _underlyingDebtAsset
        );

        uint256 collateralAssetUnit = 10 ** _pTokenDecimals;
        uint256 debtAssetUnit = 10 ** _debtTokenDecimals;
        // This is the base collateral to liquidate based on the given debt to cover
        uint256 baseCollateralLiquidateAmount = (
            (debtAssetPrice * _debtToCover * collateralAssetUnit)
        ) / (collateralPrice * debtAssetUnit);

        uint256 maxCollateralToLiquidate = baseCollateralLiquidateAmount
            .percentMul(liquidationBonus);

        if (maxCollateralToLiquidate > _userCollateralBalance) {
            actualCollateralAmount = _userCollateralBalance;

            actualDebtAmount = ((collateralPrice *
                actualCollateralAmount *
                debtAssetUnit) / (debtAssetPrice * collateralAssetUnit))
                .percentDiv(liquidationBonus);
        } else {
            actualCollateralAmount = maxCollateralToLiquidate;
            actualDebtAmount = _debtToCover;
        }
    }

    struct GetUserDataLocalVars {
        // Total Stuff
        uint256 healthFactor;
        uint256 totalCollateralInBaseCurrency;
        uint256 totalDebtInBaseCurrency;
        uint256 avgLtv;
        uint256 avgLiquidationThreshold;
        // Reserve Specific
        address currUnderlyingToken;
        uint256 ltv;
        uint256 liqThreshold;
        uint256 assetPrice;
        uint256 assetUnit;
    }

    function _getUserData(
        address _user
    ) internal view returns (uint256, uint256, uint256, uint256, uint256) {
        GetUserDataLocalVars memory vars;
        DataTypes.UserConfigurationMap memory userConfig = PoolManagerStorage
            .poolManagerStorage()
            .userConfig[_user];

        if (userConfig.isEmpty()) {
            return (type(uint256).max, 0, 0, 0, 0);
        }

        uint256 assetsLength = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssetsList
            .length;

        for (uint256 i; i < assetsLength; i++) {
            if (!userConfig.isUsingAsCollateralOrBorrowing(i)) {
                continue;
            }

            vars.currUnderlyingToken = PoolManagerStorage
                .poolManagerStorage()
                .supportedAssetsList[i];

            DataTypes.SupportedAsset storage asset = PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[vars.currUnderlyingToken];

            // assetPrice & assetUnit should not be able to be manipulatable maliciously
            // Therefore underflow/overflow errors should not occur

            unchecked {
                (vars.ltv, vars.liqThreshold, , , , ) = asset
                    .config
                    .getParams();
                // assetPrice should be in 8 decimals and not an infinitely large number
                vars.assetPrice = WitnetOracleStorage._getAssetPrice(
                    vars.currUnderlyingToken
                );
                // Assets are only added by owner, therefore no token decimals should be infinitely high
                vars.assetUnit = 10 ** asset.config.getDecimals();
                if (userConfig.isUsingAsCollateral(i)) {
                    uint256 userBalanceInBaseCurrency = (IERC20(asset.pToken)
                        .balanceOf(_user) * vars.assetPrice) / vars.assetUnit;
                    // Should not overflow as totalCollateral cannot be a big enough number
                    vars
                        .totalCollateralInBaseCurrency += userBalanceInBaseCurrency;

                    if (vars.ltv != 0) {
                        vars.avgLtv += userBalanceInBaseCurrency * vars.ltv;
                    }

                    // Should not overflow as liquidationThreshold is set by owner
                    vars.avgLiquidationThreshold +=
                        userBalanceInBaseCurrency *
                        vars.liqThreshold;
                }

                if (userConfig.isBorrowing(i)) {
                    // Should not overflow as totalDebt cannot be a big enough number
                    vars.totalDebtInBaseCurrency +=
                        (IERC20(asset.debtToken).balanceOf(_user) *
                            vars.assetPrice) /
                        vars.assetUnit;
                }
            }
        }

        unchecked {
            // Impossible to underflow as always divided by fixed number `totalCollateralInBaseCurrency`
            vars.avgLiquidationThreshold = vars.totalCollateralInBaseCurrency !=
                0
                ? vars.avgLiquidationThreshold /
                    vars.totalCollateralInBaseCurrency
                : 0;

            vars.avgLtv = vars.totalCollateralInBaseCurrency != 0
                ? vars.avgLtv / vars.totalCollateralInBaseCurrency
                : 0;
            // Should not be possible to over/underflow as `healthFactor` calc represents a ratio
            vars.healthFactor = calculateHealthFactorFromBalances(
                vars.totalCollateralInBaseCurrency,
                vars.totalDebtInBaseCurrency,
                vars.avgLiquidationThreshold
            );
        }

        return (
            vars.healthFactor,
            vars.totalCollateralInBaseCurrency,
            vars.totalDebtInBaseCurrency,
            vars.avgLtv,
            vars.avgLiquidationThreshold
        );
    }

    function _calcLinearInterest(
        uint256 _rate,
        uint256 _lastUpdateTimestamp
    ) internal view returns (uint256) {
        unchecked {
            uint256 result = _rate * (block.timestamp - _lastUpdateTimestamp);

            result = result / PoolManagerStorage.SECONDS_PER_YEAR;
            return WadRayMath.RAY + result;
        }
    }

    function _calcCompoundedInterest(
        uint256 _rate,
        uint256 _lastUpdateTimestamp
    ) internal view returns (uint256) {
        uint256 exp = block.timestamp - uint256(_lastUpdateTimestamp);

        if (exp == 0) {
            return WadRayMath.RAY;
        }

        uint256 expMinusOne;
        uint256 expMinusTwo;
        uint256 basePowerTwo;
        uint256 basePowerThree;

        unchecked {
            expMinusOne = exp - 1;

            expMinusTwo = exp > 2 ? exp - 2 : 0;

            basePowerTwo =
                _rate.rayMul(_rate) /
                (PoolManagerStorage.SECONDS_PER_YEAR *
                    PoolManagerStorage.SECONDS_PER_YEAR);
            basePowerThree =
                basePowerTwo.rayMul(_rate) /
                PoolManagerStorage.SECONDS_PER_YEAR;
        }

        uint256 secondTerm = exp * expMinusOne * basePowerTwo;
        unchecked {
            secondTerm /= 2;
        }

        uint256 thirdTerm = exp * expMinusOne * expMinusTwo * basePowerThree;
        unchecked {
            thirdTerm /= 6;
        }

        return
            WadRayMath.RAY +
            (_rate * exp) /
            PoolManagerStorage.SECONDS_PER_YEAR +
            secondTerm +
            thirdTerm;
    }

    //**Pure*********************************************************//.

    function _scaleUpAmount(
        uint256 _amount,
        uint256 _index
    ) private pure returns (uint256) {
        return _amount.rayMul(_index);
    }

    struct CalculateInterestRateParams {
        uint256 totalDebt;
        uint256 totalLiquidity;
        uint256 variableSlope1;
        uint256 variableSlope2;
        uint256 optimalUtilizationRate;
        uint256 borrowReserveRate;
    }

    function _calcInterestRates(
        CalculateInterestRateParams memory _params
    ) private pure returns (uint256 supplyRate, uint256 borrowRate) {
        /**
         * Should not overflow/underflow as vars such as optimalUtilizationRate, variableSlope1, variableSlope2 and   are pre-determined in `safe` ranges
         * And vars that can be manipulated i.e. totalLiquidity & totalDebt are calculated in ratios
         */
        unchecked {
            uint256 utilizationRatio = 0;

            utilizationRatio = _params.totalLiquidity != 0
                ? _params.totalDebt.rayDiv(_params.totalLiquidity)
                : 0;

            if (utilizationRatio > _params.optimalUtilizationRate) {
                uint256 excessUtilizationRatio = utilizationRatio -
                    _params.optimalUtilizationRate;

                uint256 excessUtilizationRate = WadRayMath.RAY -
                    _params.optimalUtilizationRate;

                borrowRate =
                    _params.variableSlope1 +
                    excessUtilizationRatio.rayDiv(excessUtilizationRate).rayMul(
                        _params.variableSlope2
                    );
            } else {
                uint256 percentageOfUtilization = utilizationRatio.rayDiv(
                    _params.optimalUtilizationRate
                );

                borrowRate = percentageOfUtilization.rayMul(
                    _params.variableSlope1
                );
            }

            supplyRate = borrowRate.rayMul(utilizationRatio).percentMul(
                PercentageMath.PERCENTAGE_FACTOR - _params.borrowReserveRate
            );
        }
    }

    /**
     * @dev Calculates the health factor from the corresponding balances
     * @param totalCollateralInBaseCurrency The total collateral in USD
     * @param totalDebtInBaseCurrency The total debt in USD
     * @param liquidationThreshold The avg liquidation threshold
     * @return The health factor calculated from the balances provided
     **/
    function calculateHealthFactorFromBalances(
        uint256 totalCollateralInBaseCurrency,
        uint256 totalDebtInBaseCurrency,
        uint256 liquidationThreshold
    ) private pure returns (uint256) {
        if (totalDebtInBaseCurrency == 0) return type(uint256).max;

        return
            (totalCollateralInBaseCurrency.percentMul(liquidationThreshold))
                .wadDiv(totalDebtInBaseCurrency);
    }

    /**
     * @notice Calculates the total debt of the user and the actual amount to liquidate depending on the health factor
     * and corresponding close factor.
     * @dev If the Health Factor is below CLOSE_FACTOR_HF_THRESHOLD, the close factor is increased to MAX_LIQUIDATION_CLOSE_FACTOR
     * @return The actual debt to liquidate as a function of the closeFactor
     */
    function _calculateDebt(
        uint256 userDebt,
        uint256 debtToCover,
        uint256 healthFactor
    ) private pure returns (uint256) {
        uint256 closeFactor = healthFactor >
            PoolManagerStorage.CLOSE_FACTOR_HF_THRESHOLD
            ? PoolManagerStorage.DEFAULT_LIQUIDATION_CLOSE_FACTOR
            : PoolManagerStorage.MAX_LIQUIDATION_CLOSE_FACTOR;

        uint256 maxLiquidatableDebt = userDebt.percentMul(closeFactor);

        uint256 actualDebtToLiquidate = debtToCover > maxLiquidatableDebt
            ? maxLiquidatableDebt
            : debtToCover;

        return actualDebtToLiquidate;
    }
}
