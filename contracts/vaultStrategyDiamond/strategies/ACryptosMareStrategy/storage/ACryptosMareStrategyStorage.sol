// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {LibDiamond} from "../../../../libraries/LibDiamond.sol";

library ACryptosMareStrategyStorage {
    bytes32 private constant AAVE_STORAGE_POSITION =
        keccak256("diamond.standard.aCryptosMareStrategy.storage");

    struct StorageLayout {
        // Third party contracts
        address source;
        bool harvestOnDeposit;
        bool init;
    }

    function strategyStorage()
        internal
        pure
        returns (StorageLayout storage aas)
    {
        bytes32 position = AAVE_STORAGE_POSITION;
        assembly {
            aas.slot := position
        }
    }

    function init(
        StorageLayout memory _initParams
    ) internal {
        require(msg.sender == LibDiamond.contractOwner(), "!owner");
        require(!strategyStorage().init, "Init already executed!");

        strategyStorage().source = _initParams.source;

        strategyStorage().harvestOnDeposit = _initParams.harvestOnDeposit;

        strategyStorage().init = true;
    }
}
