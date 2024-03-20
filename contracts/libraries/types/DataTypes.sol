// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.17;

library DataTypes {
    struct AssetConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: Asset as collateral is enabled
        //bit 57: Deposit is enabled
        //bit 58: borrowing is enabled
        //bit 80-115 borrow limit in whole tokens, borrowCap == 0 => no cap
        //bit 116-151 supply limit in whole tokens, supplyCap == 0 => no cap
        //bit 152-159: Reserve ID
        //bit 160-175: Max-vault capital efficiency in BP
        uint256 data;
    }

    struct UserConfigurationMap {
        uint256 data;
    }

    struct SupportedAsset {
        address pToken;
        address debtToken;
        address vault;
        // Supply interest strategy
        uint128 variableSlope1;
        uint128 variableSlope2;
        uint216 optimalUtilizationRate;
        // When reserves were last updated
        uint40 lastUpdateTimestamp;
        // Amount put in vault earning yield
        uint256 amountWorked;
        // the current supply interest rate. Expressed in ray
        uint128 currentSupplyRate;
        // the current borrow interest rate. Expressed in ray
        uint128 currentBorrowRate;
        // the total liquidity being supplied
        uint256 totalLiquidity;
        // the total debt being borrowed
        uint256 totalDebt;
        // the current supply index. Expressed in ray
        uint128 supplyIndex;
        // the current borrow index. Expressed in ray
        uint128 borrowIndex;
        // Vault Deposit Fee (Get paid to deposit logic)
        uint256 vaultDepositFees;
        // Total rewards that has been claimed by users
        uint256 rewardsClaimed;
        // Total Rewards Earned from Idle Liquidity
        uint256 accRewards;
        // Total farm fees Earned from Idle Liquidity
        uint256 farmFeesClaimed;
        // Accumulated Reward Per Share
        uint256 accRewardPerShare;
        AssetConfigurationMap config;

        // Deposit to vault status enabled
        bool depositToVaultStatus;
    }

    struct UserRewards {
        uint256 rewardDebt;
        uint256 rewardsOwed;
    }

    struct PoolStorage {
        uint256 reservesCount;
        // underlyingAsset => SupportedAsset
        mapping(address => SupportedAsset) supportedAssets;
        address[] supportedAssetsList;
        // underlyingAsset => user address => UserRewards
        mapping(address => mapping(address => UserRewards)) userRewards;
        // user address => UserConfigurationMap
        mapping(address => UserConfigurationMap) userConfig;

        // LiquidatorAddress
        address liquidator;
    }
}
