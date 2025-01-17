// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.17;

import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title UserConfiguration library
 * @author Aave
 * @notice Implements the bitmap logic to handle the user configuration
 */
library UserConfiguration {
    uint256 internal constant BORROWING_MASK =
        0x5555555555555555555555555555555555555555555555555555555555555555;

    /**
     * @dev Sets if the user is borrowing the reserve identified by reserveId
     * @param self The configuration object
     * @param reserveId The index of the reserve in the bitmap
     * @param borrowing True if the user is borrowing the reserve, false otherwise
     **/
    function setBorrowing(
        DataTypes.UserConfigurationMap storage self,
        uint256 reserveId,
        bool borrowing
    ) internal {
        require(reserveId < 128);
        self.data =
            (self.data & ~(1 << (reserveId * 2))) |
            (uint256(borrowing ? 1 : 0) << (reserveId * 2));
    }

    /**
     * @dev Sets if the user is using as collateral the reserve identified by reserveId
     * @param self The configuration object
     * @param reserveId The index of the reserve in the bitmap
     * @param usingAsCollateral True if the user is usin the reserve as collateral, false otherwise
     **/
    function setUsingAsCollateral(
        DataTypes.UserConfigurationMap storage self,
        uint256 reserveId,
        bool usingAsCollateral
    ) internal {
        require(reserveId < 128);
        self.data =
            (self.data & ~(1 << (reserveId * 2 + 1))) |
            (uint256(usingAsCollateral ? 1 : 0) << (reserveId * 2 + 1));
    }

    /**
     * @dev Used to validate if a user has been using the reserve for borrowing or as collateral
     * @param self The configuration object
     * @param reserveId The index of the reserve in the bitmap
     * @return True if the user has been using a reserve for borrowing or as collateral, false otherwise
     **/
    function isUsingAsCollateralOrBorrowing(
        DataTypes.UserConfigurationMap memory self,
        uint256 reserveId
    ) internal pure returns (bool) {
        require(reserveId < 128);
        return (self.data >> (reserveId * 2)) & 3 != 0;
    }

    /**
     * @dev Used to validate if a user has been using the reserve for borrowing
     * @param self The configuration object
     * @param reserveId The index of the reserve in the bitmap
     * @return True if the user has been using a reserve for borrowing, false otherwise
     **/
    function isBorrowing(
        DataTypes.UserConfigurationMap memory self,
        uint256 reserveId
    ) internal pure returns (bool) {
        require(reserveId < 128);
        return (self.data >> (reserveId * 2)) & 1 != 0;
    }

    /**
     * @dev Used to validate if a user has been using the reserve as collateral
     * @param self The configuration object
     * @param reserveId The index of the reserve in the bitmap
     * @return True if the user has been using a reserve as collateral, false otherwise
     **/
    function isUsingAsCollateral(
        DataTypes.UserConfigurationMap memory self,
        uint256 reserveId
    ) internal pure returns (bool) {
        require(reserveId < 128);
        return (self.data >> (reserveId * 2 + 1)) & 1 != 0;
    }

    /**
     * @dev Used to validate if a user has been borrowing from any reserve
     * @param self The configuration object
     * @return True if the user has been borrowing any reserve, false otherwise
     **/
    function isBorrowingAny(
        DataTypes.UserConfigurationMap memory self
    ) internal pure returns (bool) {
        return self.data & BORROWING_MASK != 0;
    }

    /**
     * @dev Used to validate if a user has not been using any reserve
     * @param self The configuration object
     * @return True if the user has been borrowing any reserve, false otherwise
     **/
    function isEmpty(
        DataTypes.UserConfigurationMap memory self
    ) internal pure returns (bool) {
        return self.data == 0;
    }
}
