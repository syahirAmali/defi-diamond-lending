// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {AccessControlStorage} from "../AccessControlFacet/storage/AccessControlStorage.sol";
import {LibPool} from "../PoolFacet/library/LibPool.sol";
import {WadRayMath} from "../../libraries/math/WadRayMath.sol";
import {DataTypes} from "../../libraries/types/DataTypes.sol";
import {AssetConfiguration} from "../../libraries/configuration/AssetConfiguration.sol";
import {PoolManagerStorage} from "./storage/PoolManagerStorage.sol";
import {PercentageMath} from "../../libraries/math/PercentageMath.sol";
import {SafeCast} from "../../libraries/math/SafeCast.sol";

interface IDiamondToken {
    function setIncentivesController(address _incentivesController) external;

    function setTreasuryAddress(address _treasuryAddress) external;
}

interface IPToken {
    function getTreasuryAddress() external view returns (address);

    function mintToTreasury(uint256 _amount, uint256 _index) external;
}

interface ITokenManagerFacet {
    function setVault(address _vault) external;

    function withdrawFunds(uint256 _amount) external;

    function transferOwnership(address _newOwner) external;

    function owner() external view returns (address);
}

contract PoolManagerFacet {
    //***************************************************************//
    //  PoolManager Facet                                            //
    //***************************************************************//

    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using SafeCast for uint256;
    using AssetConfiguration for DataTypes.AssetConfigurationMap;

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
    event SetVault(address indexed underlyingAsset, address vault);
    event SetMaxCapitalEfficiency(
        address indexed underlyingAsset,
        uint256 maxCapitalEfficiencyBp
    );
    event SetTeam(address teamAddress, uint256 teamFee);
    event SetTreasury(address treasury);
    event SetLiquidator(address liquidator);
    event WithdrawAllWorkedFunds(address indexed underlyingAsset);
    event EmergencyWithdrawAllWorkedFunds(
        address indexed underlyingAsset,
        bool status
    );
    event SetPoolParams(
        address indexed underlyingAsset,
        uint256 variableSlope1,
        uint256 variableSlope2,
        uint256 optimalUtilizationRate
    );
    event AssetDepositBorrowEnabled(
        address indexed underlyingAsset,
        bool depositEnabled,
        bool borrowEnabled
    );
    event SetLiquidationPool(
        address indexed underlyingAsset,
        uint256 loanToValue,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    );
    event SetSupplyLimit(address indexed underlyingAsset, uint256 limit);
    event SetDebtLimit(address indexed underlyingAsset, uint256 limit);
    event TokenOwnershipTransfered(address underlyingAddress, address newOwner);
    event SetBorrowReserveFactor(
        address underlyingAsset,
        uint256 reserveFactor
    );
    event SetFarmingReserveFactor(
        address underlyingAsset,
        uint256 reserveFactor
    );
    event VaultDepositStatus(address underlyingAsset, bool status);

    //**Setters******************************************************//

    /// @notice withdraws all of the worked amount from the vault of an underlyingAsset
    /// @param _underlyingAsset, the underlyingAsset to withdraw worked amount
    function withdrawAllWorkedFunds(address _underlyingAsset) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        LibPool._assetWithdrawAllWorkedFunds(_underlyingAsset);

        emit WithdrawAllWorkedFunds(_underlyingAsset);
    }

    // @notice withdraws all of the worked amount from the vault of an underlyingAsset and also disables deposit to vault status
    // @param _underlyingAsset, the underlyingAsset to withdraw worked amount
    function emergencyWithdrawAllWorkedFunds(
        address _underlyingAsset
    ) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        LibPool._assetWithdrawAllWorkedFunds(_underlyingAsset);
        bool status = _setDepositToVaultStatus(_underlyingAsset, false);

        emit EmergencyWithdrawAllWorkedFunds(_underlyingAsset, status);
    }

    function workFunds(address _underlyingAsset, uint256 _amount) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        LibPool._workFunds(_underlyingAsset, _amount, false);
    }

    /// @notice sets pool params of an underlying asset
    /// @notice can only be called by the diamond admin
    /// @param _underlyingAsset, the asset to set the pool params
    /// @param _variableSlope1, variable slope1 config value
    /// @param _variableSlope2, variable slope2 config value
    /// @param _optimalUtilizationRate, the optimial utilization rate for the underlying asset's pool
    function setPoolParams(
        address _underlyingAsset,
        uint256 _variableSlope1,
        uint256 _variableSlope2,
        uint256 _optimalUtilizationRate
    ) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];
        asset.variableSlope1 = _variableSlope1.toUint128();
        asset.variableSlope2 = _variableSlope2.toUint128();
        asset.optimalUtilizationRate = uint216(_optimalUtilizationRate);

        emit SetPoolParams(
            _underlyingAsset,
            _variableSlope1,
            _variableSlope2,
            _optimalUtilizationRate
        );
    }

    /// @notice sets the vault for a specific underlying asset
    /// @param _underlyingAsset, the underlyingAsset address to be set
    /// @param _vault, the vault address to be set
    /// @param _maxCapitalEfficiencyBp, the max capital efficiency to be achieved by vault
    function setVault(
        address _underlyingAsset,
        address _vault,
        uint256 _maxCapitalEfficiencyBp
    ) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        ITokenManagerFacet(
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .pToken
        ).setVault(_vault);

        if (_maxCapitalEfficiencyBp > 0) {
            DataTypes.AssetConfigurationMap memory config = PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .config;

            config.setMaxCapitalEfficiency(_maxCapitalEfficiencyBp);

            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .config = config;

            emit SetMaxCapitalEfficiency(
                _underlyingAsset,
                _maxCapitalEfficiencyBp
            );
        }

        emit SetVault(_underlyingAsset, _vault);
    }

    /// @notice sets the vault for a specific underlying asset
    /// @param _underlyingAsset, the underlyingAsset address to be set
    /// @param _maxCapitalEfficiencyBp, the max capital efficiency to be achieved by vault
    function setMaxCapitalEfficiencyBp(
        address _underlyingAsset,
        uint256 _maxCapitalEfficiencyBp
    ) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        DataTypes.AssetConfigurationMap memory config = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config;

        config.setMaxCapitalEfficiency(_maxCapitalEfficiencyBp);

        PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config = config;

        emit SetMaxCapitalEfficiency(_underlyingAsset, _maxCapitalEfficiencyBp);
    }

    /// @notice Sets the treasury address of the protocol
    /// @param _treasuryAddress, address to be set as treasury address
    function setTreasuryAddress(
        address _underlyingAsset,
        address _treasuryAddress
    ) external {
        LibDiamond.enforceIsContractOwner();

        IDiamondToken(
            PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .pToken
        ).setTreasuryAddress(_treasuryAddress);

        emit SetTreasury(_treasuryAddress);
    }

    function setIncentivesController(
        address _underlyingAsset,
        address _incentivesController,
        bool _isDebtToken
    ) external {
        LibDiamond.enforceIsContractOwner();

        if (_isDebtToken) {
            IDiamondToken(
                PoolManagerStorage
                    .poolManagerStorage()
                    .supportedAssets[_underlyingAsset]
                    .debtToken
            ).setIncentivesController(_incentivesController);
        } else {
            IDiamondToken(
                PoolManagerStorage
                    .poolManagerStorage()
                    .supportedAssets[_underlyingAsset]
                    .pToken
            ).setIncentivesController(_incentivesController);
        }
    }

    /// @notice Sets the liquidator address of the protocol
    /// @param _liquidatorAddress, address to be set as treasury address
    function setLiquidatorAddress(address _liquidatorAddress) external {
        LibDiamond.enforceIsContractOwner();

        PoolManagerStorage.poolManagerStorage().liquidator = _liquidatorAddress;
        emit SetLiquidator(_liquidatorAddress);
    }

    /// @notice sets the deposit and borrowing status for an underlying asset
    /// @param _underlyingAsset, the asset to enable or disable deposit and borrow
    /// @param depositEnabled, state of deposit for the underlying asset
    /// @param borrowEnabled, state of the borrow for the underlying asset
    function setAssetDepositBorrowEnabled(
        address _underlyingAsset,
        bool depositEnabled,
        bool borrowEnabled
    ) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        DataTypes.AssetConfigurationMap memory config = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config;

        config.setDepositEnabled(depositEnabled);

        config.setBorrowEnabled(borrowEnabled);

        PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config = config;

        emit AssetDepositBorrowEnabled(
            _underlyingAsset,
            depositEnabled,
            borrowEnabled
        );
    }

    /// @notice sets the liquidation pool details for a particular underlying asset
    /// @param _underlyingAsset, the underlying asset for the liquidation pool
    /// @param _loanToValue, ltv value for the asset
    /// @param _liquidationThreshold, liquidation threshold for the asset
    /// @param _liquidationBonus, the liquidation bonus for liquidators
    function setLiquidationPool(
        address _underlyingAsset,
        uint256 _loanToValue,
        uint256 _liquidationThreshold,
        uint256 _liquidationBonus
    ) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        DataTypes.AssetConfigurationMap memory config = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config;

        config.setLtv(_loanToValue);

        config.setLiquidationThreshold(_liquidationThreshold);

        config.setLiquidationBonus(_liquidationBonus);

        PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config = config;

        emit SetLiquidationPool(
            _underlyingAsset,
            _loanToValue,
            _liquidationThreshold,
            _liquidationBonus
        );
    }

    /// @notice sets the supply limit
    /// @notice can only be called by the diamond admin
    /// @param _underlyingAsset, the asset for setting the supply limit
    /// @param _limit, the limit value for the underlying asset supply
    function setSupplyLimit(address _underlyingAsset, uint256 _limit) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        DataTypes.AssetConfigurationMap memory config = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config;

        config.setSupplyLimit(_limit);

        PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config = config;

        emit SetSupplyLimit(_underlyingAsset, _limit);
    }

    /// @notice sets the debt limit
    /// @notice can only be called by the diamond admin
    /// @param _underlyingAsset, the asset for setting the debt limit
    /// @param _limit, the limit value for the underlying asset debt
    function setDebtLimit(address _underlyingAsset, uint256 _limit) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        DataTypes.AssetConfigurationMap memory config = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config;

        config.setDebtLimit(_limit);

        PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config = config;

        emit SetDebtLimit(_underlyingAsset, _limit);
    }

    function setBorrowReserveFactor(
        address _underlyingAsset,
        uint256 _borrowReserveFactor
    ) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        DataTypes.AssetConfigurationMap memory config = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config;

        config.setBorrowReserveFactor(_borrowReserveFactor);

        PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config = config;

        emit SetBorrowReserveFactor(_underlyingAsset, _borrowReserveFactor);
    }

    function setFarmingReserveFactor(
        address _underlyingAsset,
        uint256 _farmingReserveFactor
    ) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        DataTypes.AssetConfigurationMap memory config = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config;

        config.setFarmingReserveFactor(_farmingReserveFactor);

        PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .config = config;

        emit SetFarmingReserveFactor(_underlyingAsset, _farmingReserveFactor);
    }

    function setDepositToVaultStatus(
        address _underlyingAsset,
        bool _depositToVaultStatus
    ) external {
        require(
            AccessControlStorage
                .accessControlStorage()
                .adminAccount[msg.sender]
                .status == true,
            "!admin"
        );

        bool status = _setDepositToVaultStatus(
            _underlyingAsset,
            _depositToVaultStatus
        );

        emit VaultDepositStatus(_underlyingAsset, status);
    }

    function _setDepositToVaultStatus(
        address _underlyingAsset,
        bool _depositToVaultStatus
    ) private returns (bool) {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        asset.depositToVaultStatus = _depositToVaultStatus;

        return asset.depositToVaultStatus;
    }

    function transferOwnership(
        address _underlyingAsset,
        address _newOwner
    ) external {
        LibDiamond.enforceIsContractOwner();

        address ptoken = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .pToken;
        address debtToken = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset]
            .debtToken;

        ITokenManagerFacet(ptoken).transferOwnership(_newOwner);

        ITokenManagerFacet(debtToken).transferOwnership(_newOwner);

        emit TokenOwnershipTransfered(_underlyingAsset, _newOwner);
    }

    function setAccRewards(
        address _underlyingAsset,
        uint256 _accRewards
    ) external {
        LibDiamond.enforceIsContractOwner();
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        asset.accRewards = _accRewards;
    }

    function tokenOwner(
        address _underlyingAsset,
        bool _isPToken
    ) external view returns (address) {
        address token = _isPToken
            ? PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .pToken
            : PoolManagerStorage
                .poolManagerStorage()
                .supportedAssets[_underlyingAsset]
                .debtToken;

        return ITokenManagerFacet(token).owner();
    }

    /// @notice Gets the liquidator address of the protocol
    function getLiquidatorAddress() external view returns (address) {
        return PoolManagerStorage.poolManagerStorage().liquidator;
    }
}
