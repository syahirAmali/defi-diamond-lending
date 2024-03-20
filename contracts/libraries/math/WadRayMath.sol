// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.17;

/**
 * @title WadRayMath library
 * @author Aave https://github.com/aave/protocol-v2/blob/master/contracts/protocol/libraries/math/WadRayMath.sol
 * @notice Provides functions to perform calculations with Wad and Ray units
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits of precision) and rays (decimal numbers
 * with 27 digits of precision)
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 **/
library WadRayMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 0.5e18;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = 0.5e27;

    uint256 internal constant WAD_RAY_RATIO = 1e9;

    /**
     * @dev Multiplies two wad, rounding half up to the nearest wad
     * @param a Wad
     * @param b Wad
     * @return The result of a*b, in wad
     **/
    function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            if (a == 0 || b == 0) {
                return 0;
            }

            require(a <= (type(uint256).max - HALF_WAD) / b);

            return (a * b + HALF_WAD) / WAD;
        }
    }

    /**
     * @dev Divides two wad, rounding half up to the nearest wad
     * @param a Wad
     * @param b Wad
     * @return The result of a/b, in wad
     **/
    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            require(b != 0);
            uint256 halfB = b / 2;

            require(a <= (type(uint256).max - halfB) / WAD);

            return (a * WAD + halfB) / b;
        }
    }

    /**
     * @dev Multiplies two ray, rounding half up to the nearest ray
     * @param a Ray
     * @param b Ray
     * @return The result of a*b, in ray
     **/
    function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            if (a == 0 || b == 0) {
                return 0;
            }

            require(a <= (type(uint256).max - HALF_RAY) / b);

            return (a * b + HALF_RAY) / RAY;
        }
    }

    /**
     * @dev Divides two ray, rounding half up to the nearest ray
     * @param a Ray
     * @param b Ray
     * @return The result of a/b, in ray
     **/
    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            require(b != 0);
            uint256 halfB = b / 2;

            require(a <= (type(uint256).max - halfB) / RAY);

            return (a * RAY + halfB) / b;
        }
    }

    /**
     * @dev Casts ray down to wad
     * @param a Ray
     * @return a casted to wad, rounded half up to the nearest wad
     **/
    function rayToWad(uint256 a) internal pure returns (uint256) {
        unchecked {
            uint256 halfRatio = WAD_RAY_RATIO / 2;
            uint256 result = halfRatio + a;
            require(result >= halfRatio);

            return result / WAD_RAY_RATIO;
        }
    }

    /**
     * @dev Converts wad up to ray
     * @param a Wad
     * @return a converted in ray
     **/
    function wadToRay(uint256 a) internal pure returns (uint256) {
        unchecked {
            uint256 result = a * WAD_RAY_RATIO;
            require(result / WAD_RAY_RATIO == a);
            return result;
        }
    }
}
