// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {WitnetOracleStorage} from "./storage/WitnetOracleStorage.sol";
import {AccessControlStorage} from "../AccessControlFacet/storage/AccessControlStorage.sol";
import {Errors} from "../../libraries/helpers/Errors.sol";
import {IWitnetOracle} from "./interfaces/IWitnetOracle.sol";

contract OracleFacet {

    //***************************************************************//
    //  Oracle Facet                                                 //
    //***************************************************************//

    //**Events*******************************************************//

    event SetAssetSources(address[] indexed assets, address[] indexed sources);
    event AssetSourceUpdated(address indexed asset, address indexed source);


    //**Setters******************************************************//

    /// @notice sets the asset sources for particular underlying assets
    /// @notice can only be called by the admin
    /// @param assets, an array of assets to set oracle sources
    /// @param sources, an array of sources that get mapped to specific underlying assets
    function setAssetSources(
        address[] calldata assets,
        address[] calldata sources
    ) external {
        require(AccessControlStorage.accessControlStorage().adminAccount[msg.sender].status == true, "!admin");
        
        uint256 assetsLength = assets.length;
        require(
            assetsLength == sources.length,
            Errors.INCONSISTENT_PARAMS_LENGTH
        );

        for (uint256 i; i < assetsLength; ) {
            WitnetOracleStorage.oracleStorage().assetSources[assets[i]] = IWitnetOracle(sources[i]);
            
            emit AssetSourceUpdated(assets[i], sources[i]);

            unchecked {
                i++;
            }
        }        
        
        emit SetAssetSources(assets, sources);
    }

    //**Getters******************************************************//

    /// @notice retrieves the asset price according to the oracle
    /// @param asset, retrieving the price of this asset
    function getAssetPrice(address asset)
        public
        view
        returns (uint256)
    {
        return WitnetOracleStorage._getAssetPrice(asset);   
    }

    /// @notice retrieves the prices of assets according to the oracle
    /// @param assets, retrieving the price of an array of assets
    function getAssetsPrices(address[] calldata assets)
        external
        view
        returns (uint256[] memory)
    {
        uint256 assetsLength = assets.length;
        uint256[] memory prices = new uint256[](assetsLength);
        for (uint256 i; i < assetsLength; ) {
            prices[i] = getAssetPrice(assets[i]);
            unchecked {
                i++;
            }
        }
        return prices;
    }

    /// @notice retrieves the source of an asset
    /// @param asset, retrieving the source of this asset
    function getSourceOfAsset(address asset)
        external
        view
        returns (address)
    {
        return address(WitnetOracleStorage.oracleStorage().assetSources[asset]);
    }
}
