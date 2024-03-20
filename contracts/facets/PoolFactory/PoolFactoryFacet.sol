// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {DataTypes} from "../../libraries/types/DataTypes.sol";
import {PoolManagerStorage} from "../PoolManagerFacet/storage/PoolManagerStorage.sol";
import {Errors} from "../../libraries/helpers/Errors.sol";
import {WadRayMath} from "../../libraries/math/WadRayMath.sol";
import {AssetConfiguration} from "../../libraries/configuration/AssetConfiguration.sol";
import {AddressRegistryStorage} from "../AddressRegistryFacet/storage/AddressRegistryStorage.sol";
import {DiamondToken} from "../../DiamondToken.sol";

contract PoolFactoryFacet {
    
    using AssetConfiguration for DataTypes.AssetConfigurationMap;
    using WadRayMath for uint256;

    struct NewAdminPoolParams {
        address underlyingAsset;
        string tokenName;
        string tokenSymbol;
        uint8 decimals;
        uint128 variableSlope1;
        uint128 variableSlope2;
        uint256 optimalUtilizationRate;
        address treasury;
        uint256 borrowReserveFactor;
        uint256 farmingReserveFactor;
        bool depositToVaultStatus;
    }

    //***************************************************************//
    //  Pool Factory Facet                                           //
    //***************************************************************//

    //**Events*******************************************************// 

    event NewAdminPool(
        address indexed underlyingAsset,
        string tokenName,
        string tokenSymbol,
        uint8 decimals,
        uint128 variableSlope1,
        uint128 variableSlope2,
        uint256 optimalUtilizationRate,
        address indexed pToken,
        address indexed debtToken,
        address treasury,
        uint256 borrowReserveFactor,
        uint256 farmingReserveFactor
    );

    //**Setters******************************************************//

    /// @notice deploys a new admin pool for lending and borrowing
    function newAdminPool(
        NewAdminPoolParams calldata _params
    ) external {
        LibDiamond.enforceIsContractOwner();
        
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_params.underlyingAsset];
        // Ensure 10**decimals won't overflow a uint256
        require(_params.decimals <= 77, Errors.TOO_MANY_DECIMALS);

        asset.pToken = _deployDiamondToken(
            address(this),
            address(this),
            AddressRegistryStorage.registryStorage().pToken,
            _params.underlyingAsset,
            string.concat("p", _params.tokenName),
            string.concat("p", _params.tokenSymbol),
            _params.decimals,
            true,
            _params.treasury
        );

        asset.debtToken = _deployDiamondToken(
            address(this),
            address(this),
            AddressRegistryStorage.registryStorage().debtToken,
            _params.underlyingAsset,
            string.concat("vd", _params.tokenName),
            string.concat("vd", _params.tokenSymbol),
            _params.decimals,
            false,
            address(0)
        );

        {
            asset.variableSlope1 = _params.variableSlope1;
            asset.variableSlope2 = _params.variableSlope2;
            asset.optimalUtilizationRate = uint216(
                _params.optimalUtilizationRate
            );

            asset.supplyIndex = uint128(WadRayMath.RAY);
            asset.borrowIndex = uint128(WadRayMath.RAY);
            asset.lastUpdateTimestamp = uint40(block.timestamp);

            asset.depositToVaultStatus = _params.depositToVaultStatus;

            DataTypes.AssetConfigurationMap memory config = asset.config;
            config.setReserveId(
                PoolManagerStorage.poolManagerStorage().reservesCount
            );
            config.setDecimals(_params.decimals);
            config.setDepositEnabled(true);
            config.setBorrowEnabled(true);
            config.setBorrowReserveFactor(_params.borrowReserveFactor);
            config.setFarmingReserveFactor(_params.farmingReserveFactor);
            asset.config = config;

            PoolManagerStorage.poolManagerStorage().supportedAssetsList.push(
                _params.underlyingAsset
            );
            PoolManagerStorage.poolManagerStorage().reservesCount += 1;
        }

        emit NewAdminPool(
            _params.underlyingAsset,
            _params.tokenName,
            _params.tokenSymbol,
            _params.decimals,
            _params.variableSlope1,
            _params.variableSlope2,
            _params.optimalUtilizationRate,
            asset.pToken,
            asset.debtToken,
            _params.treasury,
            _params.borrowReserveFactor,
            _params.farmingReserveFactor
        );    
    }

    function _deployDiamondToken(
        address _contractOwner,
        address _diamond,
        address _tokenImplementation,
        address _underlyingAsset,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        bool _isPToken,
        address _treasury
    ) internal returns (address) {
        // set params for diamond token
        DiamondToken.TokenInit memory params;

        params._contractOwner = _contractOwner;
        params._diamond = _diamond;
        params._diamondCutFacetImpl = 
            AddressRegistryStorage.registryStorage().diamondCut;
        params._poolImpl = address(this);
        params._tokenImplementation = _tokenImplementation;
        params._underlyingAsset = _underlyingAsset;
        params._tokenManagerImplementation = 
            AddressRegistryStorage.registryStorage().tokenManager;
        params._accessControlImplementation = 
            AddressRegistryStorage.registryStorage().accessControl;
        params._name = _name;
        params._symbol = _symbol;
        params._decimals = _decimals;
        params._isPToken = _isPToken;
        params._treasury = _treasury;

        DiamondToken diamondToken = new DiamondToken(params);

        return address(diamondToken);
    }
}
