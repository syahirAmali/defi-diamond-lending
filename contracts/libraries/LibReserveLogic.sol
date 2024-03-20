// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {DataTypes} from "./types/DataTypes.sol";
import {WadRayMath} from "./math/WadRayMath.sol";
import {PoolManagerStorage} from "../facets/PoolManagerFacet/storage/PoolManagerStorage.sol";

library LibReserveLogic {
    using WadRayMath for uint256;

    function _getAssetNormalizedSupplyIndex(
        address _underlyingAsset
    ) internal view returns (uint256) {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        return _getNormalizedSupplyIndex(asset);
    }

    function _getNormalizedSupplyIndex(
        DataTypes.SupportedAsset storage asset
    ) internal view returns (uint256) {
        if (block.timestamp == asset.lastUpdateTimestamp) {
            return asset.supplyIndex;
        }

        return
            _calcLinearInterest(
                asset.currentSupplyRate,
                asset.lastUpdateTimestamp
            ).rayMul(asset.supplyIndex);
    }

    function _getAssetNormalizedBorrowIndex(
        address _underlyingAsset
    ) internal view returns (uint256) {
        DataTypes.SupportedAsset storage asset = PoolManagerStorage
            .poolManagerStorage()
            .supportedAssets[_underlyingAsset];

        return _getNormalizedBorrowIndex(asset);
    }

    function _getNormalizedBorrowIndex(
        DataTypes.SupportedAsset storage asset
    ) internal view returns (uint256) {
        if (block.timestamp == asset.lastUpdateTimestamp) {
            return asset.borrowIndex;
        }

        // Should not be possible to overflow/underflow as these numbers cannot be manipulated easily
        return
            _calcCompoundedInterest(
                asset.currentBorrowRate,
                asset.lastUpdateTimestamp
            ).rayMul(asset.borrowIndex);
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
}
