// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {PoolManagerStorage} from "../PoolManagerFacet/storage/PoolManagerStorage.sol";
import {LibPool} from "../PoolFacet/library/LibPool.sol";
import {LibReserveLogic} from "../../libraries/LibReserveLogic.sol";
import {WadRayMath} from "../../libraries/math/WadRayMath.sol";
import {DataTypes} from "../../libraries/types/DataTypes.sol";
import {AssetConfiguration} from "../../libraries/configuration/AssetConfiguration.sol";
import {PercentageMath} from "../../libraries/math/PercentageMath.sol";
import {UserConfiguration} from "../../libraries/configuration/UserConfiguration.sol";

contract PoolDataFacet {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using AssetConfiguration for DataTypes.AssetConfigurationMap;
    using UserConfiguration for DataTypes.UserConfigurationMap;

    //***************************************************************//
    //  Pool Data Facet                                              //
    //***************************************************************//

    //**Getters******************************************************//

    /// @notice gets the pToken address based on the underlying asset
    /// @param _underlyingAsset, the asset to check for pToken
    function getPToken(
        address _underlyingAsset
    ) external view returns (address) {
        return
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .pToken;
    }

    /// @notice gets the debtToken address based on the underlying asset
    /// @param _underlyingAsset, the asset to check for debtToken
    function getDebtToken(
        address _underlyingAsset
    ) external view returns (address) {
        return
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .debtToken;
    }

    /// @notice gets the borrow rate based on the underlying asset
    /// @param _underlyingAsset, the asset to check for borrow rate
    function getBorrowRate(
        address _underlyingAsset
    ) external view returns (uint256) {
        return
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .currentBorrowRate;
    }

    /// @notice gets the supply rate based on the underlying asset
    /// @param _underlyingAsset, the asset to check for supply rate
    function getSupplyRate(
        address _underlyingAsset
    ) external view returns (uint256) {
        return
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .currentSupplyRate;
    }

    /// @notice gets the total liquidity based on the underlying asset
    /// @param _underlyingAsset, the asset to check for total liquidity
    function getTotalLiquidity(
        address _underlyingAsset
    ) external view returns (uint256) {
        return
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .totalLiquidity;
    }

    /// @notice gets the total debt based on the underlying asset
    /// @param _underlyingAsset, the asset to check for total debt
    function getTotalDebt(
        address _underlyingAsset
    ) external view returns (uint256) {
        return
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .totalDebt;
    }

    /// @notice gets the supported asset based on position index
    /// @param _index, the index value to get the supported asset
    function getSupportedAsset(uint256 _index) external view returns (address) {
        return
            PoolManagerStorage.poolManagerStorage().supportedAssetsList[_index];
    }

    /// @notice gets all supported assets
    function getReservesList() external view returns (address[] memory) {
        return PoolManagerStorage.poolManagerStorage().supportedAssetsList;
    }

    /// @notice gets the liquidation config of a specific underlying asset
    /// @param _underlyingAsset, the asset to get the liquidation config
    function getLiquidationConfig(
        address _underlyingAsset
    )
        external
        view
        returns (
            uint256 loanToValue,
            uint256 liquidationThreshold,
            uint256 liquidationBonus
        )
    {
        (
            loanToValue,
            liquidationThreshold,
            liquidationBonus,
            ,
            ,

        ) = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config
            .getParams();
    }

    /// @notice gets the status flags for an underlying asset
    /// @param _underlyingAsset, the asset to get the status flags
    function getFlags(
        address _underlyingAsset
    )
        external
        view
        returns (
            bool assetAsCollateral,
            bool depositEnabled,
            bool borrowEnabled
        )
    {
        (assetAsCollateral, depositEnabled, borrowEnabled) = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config
            .getFlags();
    }

    /// @notice gets the supply and debt limit of an underlying asset
    /// @param _underlyingAsset, the asset to get the supply and debt limit
    function getSupplyAndDebtLimit(
        address _underlyingAsset
    ) external view returns (uint256 supplyLimit, uint256 debtLimit) {
        (, , , , supplyLimit, debtLimit) = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config
            .getParams();
    }

    /// @notice gets the reserve fees of an underlying asset
    /// @param _underlyingAsset, the asset to get the reserve fees
    function getReserveFees(
        address _underlyingAsset
    ) external view returns (uint256 vaultDepositFees) {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        vaultDepositFees = asset.vaultDepositFees;
    }

    /// @notice gets the supply interest config of an underlying asset
    /// @param _underlyingAsset, the asset to get the supply interest config
    function getInterestConfig(
        address _underlyingAsset
    )
        external
        view
        returns (
            uint256 variableSlope1,
            uint256 variableSlope2,
            uint256 optimalUtilizationRate
        )
    {
        variableSlope1 = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .variableSlope1;
        variableSlope2 = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .variableSlope2;
        optimalUtilizationRate = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .optimalUtilizationRate;
    }

    /// @notice gets the amount worked of an underlying asset
    function getAmountWorked(
        address _underlyingAsset
    ) external view returns (uint256) {
        return
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .amountWorked;
    }

    /// @notice gets the total vault reward of an underlying asset
    function getTotalVaultRewards(
        address _underlyingAsset
    )
        external
        view
        returns (uint256 totalRewards, uint256 vaultDepositRewards)
    {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];
        totalRewards = LibPool._currVaultRewards(asset);
        vaultDepositRewards = asset.vaultDepositFees;

        uint256 tokenTotalReceived = totalRewards + asset.rewardsClaimed;
        if (asset.accRewards > tokenTotalReceived)
            return (totalRewards, vaultDepositRewards);

        uint256 newRewards = tokenTotalReceived - asset.accRewards;

        uint256 accruedFees = newRewards.percentMul(
            asset.config.getFarmingReserveFactor()
        );

        vaultDepositRewards += accruedFees.percentMul(
            PoolManagerStorage.VAULT_DEPOSIT_FEES
        );
    }

    /// @notice gets the reserve id of an underlying asset
    function getReserveId(
        address _underlyingAsset
    ) external view returns (uint256) {
        return
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .config
                .getReserveId();
    }

    /// @notice Get the normalized supply index of an underlying asset
    function getNormalizedSupplyIndex(
        address _underlyingAsset
    ) public view returns (uint256) {
        return LibReserveLogic._getAssetNormalizedSupplyIndex(_underlyingAsset);
    }

    /// @notice Get the normalized borrow index of an underlying asset
    function getNormalizedBorrowIndex(
        address _underlyingAsset
    ) public view returns (uint256) {
        return LibReserveLogic._getAssetNormalizedBorrowIndex(_underlyingAsset);
    }

    /// @notice gets the user data from a specific address
    function getUserData(
        address _user
    )
        external
        view
        returns (
            uint256 healthFactor,
            uint256 totalCollateralInBaseCurrency,
            uint256 totalDebtInBaseCurrency,
            uint256 avgLtv,
            uint256 avgLiquiditationThreshold
        )
    {
        (
            healthFactor,
            totalCollateralInBaseCurrency,
            totalDebtInBaseCurrency,
            avgLtv,
            avgLiquiditationThreshold
        ) = LibPool._getUserData(_user);
    }

    /// @notice gets the pending vault rewards of an underlying asset for a user
    function getPendingVaultRewards(
        address _underlyingAsset,
        address _user
    ) external view returns (uint256) {
        return LibPool._pendingRewards(_underlyingAsset, _user);
    }

    /// @notice gets the max capital efficiency of an underlying asset pool
    function getMaxCapitalEfficiency(
        address _underlyingAsset
    ) external view returns (uint256) {
        return
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .config
                .getMaxCapitalEfficiency();
    }

    /// @notice gets the pool rewards data for an underlying asset
    function getPoolRewardsData(
        address _underlyingAsset
    )
        external
        view
        returns (
            uint256 accRewardPerShare_,
            uint256 rewardsClaimed_,
            uint256 accRewards_
        )
    {
        DataTypes.SupportedAsset storage pool = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        accRewardPerShare_ = pool.accRewardPerShare;
        rewardsClaimed_ = pool.rewardsClaimed;
        accRewards_ = pool.accRewards;
    }

    /// @notice gets the user rewards data for an underlying asset
    function getUserRewardsData(
        address _underlyingAsset,
        address _user
    ) external view returns (uint256 rewardDebt_, uint256 rewardsOwed_) {
        DataTypes.UserRewards storage user = PoolManagerStorage
            .poolManagerStorage()
            .userRewards[_underlyingAsset][_user];

        rewardDebt_ = user.rewardDebt;
        rewardsOwed_ = user.rewardsOwed;
    }

    /// @notice gets user underlying asset status as collateral
    function getUserIsUsingAsCollateral(
        address _underlyingAsset,
        address _user
    ) external view returns (bool) {
        DataTypes.SupportedAsset memory pAsset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        return
            PoolManagerStorage
                .poolManagerStorage()
                .userConfig[_user]
                .isUsingAsCollateral(pAsset.config.getReserveId());
    }

    // Returns the reserve factor for borrowing & farming
    function getReserveFactors(
        address _underlyingAsset
    ) external view returns (uint256 borrowFactor, uint256 farmingFactor) {
        borrowFactor = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config
            .getBorrowReserveFactor();

        farmingFactor = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config
            .getFarmingReserveFactor();
    }

    function getDepositToVaultStatus(
        address _underlyingAsset
    ) external view returns (bool status_) {
        status_ = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .depositToVaultStatus;
    }
}
