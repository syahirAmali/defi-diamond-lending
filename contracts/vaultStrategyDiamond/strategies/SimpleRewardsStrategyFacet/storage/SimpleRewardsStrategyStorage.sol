// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {LibDiamond} from "../../../../libraries/LibDiamond.sol";

library LibSimpleRewardsStrategyStorage {
    bytes32 private constant STORAGE_POSITION =
        keccak256("diamond.standard.simpleRewards.storage");

    struct StrategyStorageLayout {
        address source;
        bool harvestOnDeposit;
        bool init;
    }

    function strategyStorage()
        internal
        pure
        returns (StrategyStorageLayout storage aas)
    {
        bytes32 position = STORAGE_POSITION;
        assembly {
            aas.slot := position
        }
    }

    function init(StrategyStorageLayout memory _initParams) internal {
        require(msg.sender == LibDiamond.contractOwner(), "!owner");
        StrategyStorageLayout storage data = strategyStorage();

        require(!data.init, "Init already executed!");

        data.source = _initParams.source;
        data.harvestOnDeposit = _initParams.harvestOnDeposit;
        data.init = true;
    }
}
