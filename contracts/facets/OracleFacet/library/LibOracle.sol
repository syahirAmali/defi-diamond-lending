// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {AggregatorInterface} from "../interfaces/AggregatorInterface.sol";
import {Errors} from "../../../libraries/helpers/Errors.sol";

library LibOracle {

    //**Storage******************************************************//~

    bytes32 private constant ORACLE_STORAGE_POSITION =
        keccak256("diamond.standard.oracle.storage");

    struct OracleStorage {
        mapping(address => AggregatorInterface) assetSources;
    }

    function oracleStorage() internal pure returns (OracleStorage storage os) {
        bytes32 position = ORACLE_STORAGE_POSITION;
        assembly {
            os.slot := position
        }
    }

    event AssetSourceUpdated(address indexed asset, address indexed source);

    //**Setters******************************************************//

    function _mapAssetsSources(
        address[] memory assets,
        address[] memory sources
    ) internal {
        uint256 assetsLength = assets.length;
        require(
            assetsLength == sources.length,
            Errors.INCONSISTENT_PARAMS_LENGTH
        );

        for (uint256 i; i < assetsLength; ) {
            oracleStorage().assetSources[assets[i]] = AggregatorInterface(
                sources[i]
            );
            emit AssetSourceUpdated(assets[i], sources[i]);

            unchecked {
                i++;
            }
        }
    }

    function _setAssetSources(
        address[] calldata assets,
        address[] calldata sources
    ) internal {
        _mapAssetsSources(assets, sources);
    }

    //**Getters******************************************************//

    function _getAssetPrice(address asset) internal view returns (uint256) {
        AggregatorInterface source = oracleStorage().assetSources[asset];

        int256 price = source.latestAnswer();

        if(price == 0){
            return uint256(1);
        }

        return uint256(price);
    }

    function _getAssetsPrices(
        address[] calldata assets
    ) internal view returns (uint256[] memory) {
        uint256 assetsLength = assets.length;
        uint256[] memory prices = new uint256[](assetsLength);
        for (uint256 i; i < assetsLength; ) {
            prices[i] = _getAssetPrice(assets[i]);
            unchecked {
                i++;
            }
        }
        return prices;
    }

    function _getSourceOfAsset(address asset) internal view returns (address) {
        return address(oracleStorage().assetSources[asset]);
    }
}
