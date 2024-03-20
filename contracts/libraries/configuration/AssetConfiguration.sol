// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.17;
import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title AssetConfiguration library
 * @author Aave V2, with custom modification by Pinjam
 * @notice Implements the bitmap logic to handle the asset configuration
 */

library AssetConfiguration {
    uint256 constant LTV_MASK =                     0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
    uint256 constant LIQUIDATION_THRESHOLD_MASK =   0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
    uint256 constant LIQUIDATION_BONUS_MASK =       0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFF; // prettier-ignore
    uint256 constant DECIMALS_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF; // prettier-ignore
    uint256 constant ASSET_AS_COLLATERAL_MASK =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant DEPOSIT_MASK =                 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant BORROW_MASK =                  0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant DEBT_LIMIT_MASK =              0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant SUPPLY_LIMIT_MASK =            0xFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant RESERVE_ID_MASK =              0xFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant MAX_CAPITAL_EFFICIENCY_MASK =  0xFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant BORROW_RESERVE_FACTOR_MASK =   0xFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant FARMING_RESERVE_FACTOR_MASK =  0xFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // prettier-ignore

    /// @dev For the LTV, the start bit is 0 (up to 15), hence no bitshifting is needed
    uint256 constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
    uint256 constant LIQUIDATION_BONUS_START_BIT_POSITION = 32;
    uint256 constant RESERVE_DECIMALS_START_BIT_POSITION = 48;
    uint256 constant IS_COLLATERAL_START_BIT_POSITION = 56;
    uint256 constant DEPOSIT_ENABLED_START_BIT_POSITION = 57;
    uint256 constant BORROW_ENABLED_START_BIT_POSITION = 58;
    uint256 constant DEBT_LIMIT_START_BIT_POSITION = 80;
    uint256 constant SUPPLY_LIMIT_START_BIT_POSITION = 116;
    uint256 constant RESERVE_ID_START_BIT_POSITION = 152;
    uint256 constant MAX_CAPITAL_EFFICIENCY_START_BIT_POSITION = 160;
    uint256 constant BORROW_RESERVE_FACTOR_START_BIT_POSITION = 176;
    uint256 constant FARMING_RESERVE_FACTOR_START_BIT_POSITION = 192;

    uint256 constant MAX_VALID_BP = 65535;
    uint256 constant MAX_VALID_DECIMALS = 255;
    uint256 constant MAX_VALID_SUPPLY_DEBT_CAP = 68719476735;
    uint256 constant MAX_VALID_RESERVE_ID = 128;

    /**
     * @dev Sets the Loan to Value of the asset
     * @param self The asset configuration
     * @param ltv the new ltv
     **/
    function setLtv(
        DataTypes.AssetConfigurationMap memory self,
        uint256 ltv
    ) internal pure {
        require(ltv <= MAX_VALID_BP);

        self.data = (self.data & LTV_MASK) | ltv;
    }

    /**
     * @dev Gets the Loan to Value of the asset
     * @param self The asset configuration
     * @return The loan to value
     **/
    function getLtv(
        DataTypes.AssetConfigurationMap storage self
    ) internal view returns (uint256) {
        return self.data & ~LTV_MASK;
    }

    /**
     * @dev Sets the liquidation threshold of the asset
     * @param self The asset configuration
     * @param threshold The new liquidation threshold
     **/
    function setLiquidationThreshold(
        DataTypes.AssetConfigurationMap memory self,
        uint256 threshold
    ) internal pure {
        require(threshold <= MAX_VALID_BP);

        self.data =
            (self.data & LIQUIDATION_THRESHOLD_MASK) |
            (threshold << LIQUIDATION_THRESHOLD_START_BIT_POSITION);
    }

    /**
     * @dev Gets the liquidation threshold of the asset
     * @param self The asset configuration
     * @return The liquidation threshold
     **/
    function getLiquidationThreshold(
        DataTypes.AssetConfigurationMap storage self
    ) internal view returns (uint256) {
        return
            (self.data & ~LIQUIDATION_THRESHOLD_MASK) >>
            LIQUIDATION_THRESHOLD_START_BIT_POSITION;
    }

    /**
     * @dev Sets the liquidation bonus of the asset
     * @param self The asset configuration
     * @param bonus The new liquidation bonus
     **/
    function setLiquidationBonus(
        DataTypes.AssetConfigurationMap memory self,
        uint256 bonus
    ) internal pure {
        require(bonus <= MAX_VALID_BP);

        self.data =
            (self.data & LIQUIDATION_BONUS_MASK) |
            (bonus << LIQUIDATION_BONUS_START_BIT_POSITION);
    }

    /**
     * @dev Gets the liquidation bonus of the asset
     * @param self The asset configuration
     * @return The liquidation bonus
     **/
    function getLiquidationBonus(
        DataTypes.AssetConfigurationMap storage self
    ) internal view returns (uint256) {
        return
            (self.data & ~LIQUIDATION_BONUS_MASK) >>
            LIQUIDATION_BONUS_START_BIT_POSITION;
    }

    /**
     * @dev Sets the decimals of the underlying asset of the asset
     * @param self The asset configuration
     * @param decimals The decimals
     **/

    function setDecimals(
        DataTypes.AssetConfigurationMap memory self,
        uint256 decimals
    ) internal pure {
        require(decimals <= MAX_VALID_DECIMALS);

        self.data =
            (self.data & DECIMALS_MASK) |
            (decimals << RESERVE_DECIMALS_START_BIT_POSITION);
    }

    /**
     * @notice Gets the decimals of the underlying asset of the asset
     * @param self The asset configuration
     * @return The decimals of the asset
     **/
    function getDecimals(
        DataTypes.AssetConfigurationMap memory self
    ) internal pure returns (uint256) {
        return
            (self.data & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION;
    }

    /**
     * @dev Enables or disables the asset usage as collateral
     * @param self The asset configuration
     * @param enabled The active state
     **/
    function setUseAsCollateral(
        DataTypes.AssetConfigurationMap memory self,
        bool enabled
    ) internal pure {
        self.data =
            (self.data & ASSET_AS_COLLATERAL_MASK) |
            (uint256(enabled ? 1 : 0) << IS_COLLATERAL_START_BIT_POSITION);
    }

    /**
     * @dev Gets the allow as collateral state of the asset
     * @param self The asset configuration
     * @return The active state
     **/
    function getUseAsCollateral(
        DataTypes.AssetConfigurationMap storage self
    ) internal view returns (bool) {
        return (self.data & ~ASSET_AS_COLLATERAL_MASK) != 0;
    }

    /**
     * @dev Enables or disables depositing
     * @param self The asset configuration
     * @param enabled True if the deposit needs to be enabled, false otherwise
     **/
    function setDepositEnabled(
        DataTypes.AssetConfigurationMap memory self,
        bool enabled
    ) internal pure {
        self.data =
            (self.data & DEPOSIT_MASK) |
            (uint256(enabled ? 1 : 0) << DEPOSIT_ENABLED_START_BIT_POSITION);
    }

    /**
     * @dev Gets the deposit state of the asset
     * @param self The asset configuration
     * @return The deposit state
     **/
    function getDepositEnabled(
        DataTypes.AssetConfigurationMap storage self
    ) internal view returns (bool) {
        return (self.data & ~DEPOSIT_MASK) != 0;
    }

    /**
     * @dev Enables or disables borrowing on the asset
     * @param self The asset configuration
     * @param enabled True if the borrowing needs to be enabled, false otherwise
     **/
    function setBorrowEnabled(
        DataTypes.AssetConfigurationMap memory self,
        bool enabled
    ) internal pure {
        self.data =
            (self.data & BORROW_MASK) |
            (uint256(enabled ? 1 : 0) << BORROW_ENABLED_START_BIT_POSITION);
    }

    /**
     * @dev Gets the borrowing state of the asset
     * @param self The asset configuration
     * @return The borrowing state
     **/
    function getBorrowEnabled(
        DataTypes.AssetConfigurationMap storage self
    ) internal view returns (bool) {
        return (self.data & ~BORROW_MASK) != 0;
    }

    /**
     * @notice Sets the borrow limit of the asset
     * @param self The asset configuration
     * @param debtLimit The borrow limit
     **/
    function setDebtLimit(
        DataTypes.AssetConfigurationMap memory self,
        uint256 debtLimit
    ) internal pure {
        require(debtLimit <= MAX_VALID_SUPPLY_DEBT_CAP);

        self.data =
            (self.data & DEBT_LIMIT_MASK) |
            (debtLimit << DEBT_LIMIT_START_BIT_POSITION);
    }

    /**
     * @notice Gets the borrow limit of the asset
     * @param self The asset configuration
     * @return The borrow limit
     **/
    function getDebtLimit(
        DataTypes.AssetConfigurationMap memory self
    ) internal pure returns (uint256) {
        return (self.data & ~DEBT_LIMIT_MASK) >> DEBT_LIMIT_START_BIT_POSITION;
    }

    /**
     * @notice Sets the supply limit of the asset
     * @param self The asset configuration
     * @param supplyLimit The supply limit
     **/
    function setSupplyLimit(
        DataTypes.AssetConfigurationMap memory self,
        uint256 supplyLimit
    ) internal pure {
        require(supplyLimit <= MAX_VALID_SUPPLY_DEBT_CAP);

        self.data =
            (self.data & SUPPLY_LIMIT_MASK) |
            (supplyLimit << SUPPLY_LIMIT_START_BIT_POSITION);
    }

    /**
     * @notice Gets the supply limit of the asset
     * @param self The asset configuration
     * @return The supply limit
     **/
    function getSupplyLimit(
        DataTypes.AssetConfigurationMap memory self
    ) internal pure returns (uint256) {
        return
            (self.data & ~SUPPLY_LIMIT_MASK) >> SUPPLY_LIMIT_START_BIT_POSITION;
    }

    /**
     * @dev Sets the reserve id of the underlying asset
     * @param self The asset configuration
     * @param id The id of the asset
     **/

    function setReserveId(
        DataTypes.AssetConfigurationMap memory self,
        uint256 id
    ) internal pure {
        require(id < MAX_VALID_RESERVE_ID);

        self.data =
            (self.data & RESERVE_ID_MASK) |
            (id << RESERVE_ID_START_BIT_POSITION);
    }

    /**
     * @notice Gets the reserve ID of the underlying asset
     * @param self The asset configuration
     * @return The id of the asset
     **/
    function getReserveId(
        DataTypes.AssetConfigurationMap memory self
    ) internal pure returns (uint256) {
        return (self.data & ~RESERVE_ID_MASK) >> RESERVE_ID_START_BIT_POSITION;
    }

    /**
     * @dev Sets the max capital efficiency of asset, 0 = infinite
     * @param self The asset configuration
     * @param maxCapitalEfficiencyBp The max capital efficiency in Basis Points
     **/
    function setMaxCapitalEfficiency(
        DataTypes.AssetConfigurationMap memory self,
        uint256 maxCapitalEfficiencyBp
    ) internal pure {
        require(maxCapitalEfficiencyBp <= 10000);

        self.data =
            (self.data & MAX_CAPITAL_EFFICIENCY_MASK) |
            (maxCapitalEfficiencyBp <<
                MAX_CAPITAL_EFFICIENCY_START_BIT_POSITION);
    }

    /**
     * @notice Gets the max capital efficiency of asset, 0 = infinite
     * @param self The asset configuration
     * @return The max capital efficiency in Basis Points
     **/
    function getMaxCapitalEfficiency(
        DataTypes.AssetConfigurationMap memory self
    ) internal pure returns (uint256) {
        return
            (self.data & ~MAX_CAPITAL_EFFICIENCY_MASK) >>
            MAX_CAPITAL_EFFICIENCY_START_BIT_POSITION;
    }

    /**
     * @dev Sets the borrow reserve factor of an asset in Basis Points
     * @param self The asset configuration
     * @param borrowReserveFactor The borrow reserve factor of asset in Basis Points
     **/
    function setBorrowReserveFactor(
        DataTypes.AssetConfigurationMap memory self,
        uint256 borrowReserveFactor
    ) internal pure {
        require(borrowReserveFactor <= 10000);

        self.data =
            (self.data & BORROW_RESERVE_FACTOR_MASK) |
            (borrowReserveFactor << BORROW_RESERVE_FACTOR_START_BIT_POSITION);
    }

    /**
     * @notice Gets the borrow reserve factor of asset in Basis Points
     * @param self The asset configuration
     * @return The borrow reserve factor of asset in Basis Points
     **/
    function getBorrowReserveFactor(
        DataTypes.AssetConfigurationMap memory self
    ) internal pure returns (uint256) {
        return
            (self.data & ~BORROW_RESERVE_FACTOR_MASK) >>
            BORROW_RESERVE_FACTOR_START_BIT_POSITION;
    }

    /**
     * @dev Sets the farming reserve factor of an asset
     * @param self The asset configuration
     * @param farmingReserveFactor The farming reserve factor of asset in Basis Points
     **/
    function setFarmingReserveFactor(
        DataTypes.AssetConfigurationMap memory self,
        uint256 farmingReserveFactor
    ) internal pure {
        require(farmingReserveFactor <= 10000);

        self.data =
            (self.data & FARMING_RESERVE_FACTOR_MASK) |
            (farmingReserveFactor << FARMING_RESERVE_FACTOR_START_BIT_POSITION);
    }

    /**
     * @notice Gets the farming reserve factor of asset in Basis Points
     * @param self The asset configuration
     * @return The farming reserve factor of asset in Basis Points
     **/
    function getFarmingReserveFactor(
        DataTypes.AssetConfigurationMap memory self
    ) internal pure returns (uint256) {
        return
            (self.data & ~FARMING_RESERVE_FACTOR_MASK) >>
            FARMING_RESERVE_FACTOR_START_BIT_POSITION;
    }

    /**
     * @dev Gets the configuration flags of the asset
     * @param self The asset configuration
     * @return The state flags representing asset as collateral, deposit enabled, borrow enabled
     **/
    function getFlags(
        DataTypes.AssetConfigurationMap storage self
    ) internal view returns (bool, bool, bool) {
        uint256 dataLocal = self.data;

        return (
            (dataLocal & ~ASSET_AS_COLLATERAL_MASK) != 0,
            (dataLocal & ~DEPOSIT_MASK) != 0,
            (dataLocal & ~BORROW_MASK) != 0
        );
    }

    /**
     * @dev Gets the configuration paramters of the asset from a memory object
     * @param self The asset configuration
     * @return LTV
     * @return Liquidation Threshold
     * @return Liquidation Bonus
     * @return Decimals
     * @return Supply Limit
     * @return Debt Limit
     **/
    function getParams(
        DataTypes.AssetConfigurationMap memory self
    )
        internal
        pure
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        return (
            self.data & ~LTV_MASK,
            (self.data & ~LIQUIDATION_THRESHOLD_MASK) >>
                LIQUIDATION_THRESHOLD_START_BIT_POSITION,
            (self.data & ~LIQUIDATION_BONUS_MASK) >>
                LIQUIDATION_BONUS_START_BIT_POSITION,
            (self.data & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION,
            (self.data & ~SUPPLY_LIMIT_MASK) >> SUPPLY_LIMIT_START_BIT_POSITION,
            (self.data & ~DEBT_LIMIT_MASK) >> DEBT_LIMIT_START_BIT_POSITION
        );
    }
}
