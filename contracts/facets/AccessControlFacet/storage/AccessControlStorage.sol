// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {Errors} from "../../../libraries/helpers/Errors.sol";
import {LibDiamond} from "../../../libraries/LibDiamond.sol";

library AccessControlStorage {

    //**Storage******************************************************//
    
    bytes32 private constant ACCESS_CONTROL_STORAGE_POSITION =
        keccak256("diamond.standard.accessControl.storage");

    struct AdminAccount {
        bool status;
    }

    struct AccessControlStorageStruct {
        mapping(address => AdminAccount) adminAccount;
    }

    function accessControlStorage()
        internal
        pure
        returns (AccessControlStorageStruct storage acs)
    {
        bytes32 position = ACCESS_CONTROL_STORAGE_POSITION;
        assembly {
            acs.slot := position
        }
    }
}
