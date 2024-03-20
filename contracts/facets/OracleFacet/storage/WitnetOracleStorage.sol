// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {Errors} from "../../../libraries/helpers/Errors.sol";
import {IWitnetOracle} from "../interfaces/IWitnetOracle.sol";

library WitnetOracleStorage {
    
    //**Storage******************************************************//~

    bytes32 private constant ORACLE_STORAGE_POSITION =
        keccak256("diamond.standard.oracle.storage");

    struct OracleStorage {
        mapping(address => IWitnetOracle) assetSources;
    }

    function oracleStorage() internal pure returns (OracleStorage storage os) {
        bytes32 position = ORACLE_STORAGE_POSITION;
        assembly {
            os.slot := position
        }
    }

    function _getAssetPrice(address asset)
        internal
        view
        returns (uint256)
    {
        IWitnetOracle source = WitnetOracleStorage.oracleStorage().assetSources[asset];
        // Price received is in 6 decimals, ensures it follows the standard 8 decimals set by chainlink
        int256 price = source.lastPrice() * 1e2;

        if(price == 0){
            return uint256(1);
        }

        return uint256(price);    
    }
}
