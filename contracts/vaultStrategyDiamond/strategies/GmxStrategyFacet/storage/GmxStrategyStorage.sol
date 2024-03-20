// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {LibDiamond} from "../../../../libraries/LibDiamond.sol";

library GmxStrategyStorage {
    bytes32 private constant GMX_STORAGE_POSITION =
        keccak256("diamond.standard.gmxStrategy.storage");

    struct GmxStorageLayout {
        // Third party contracts
        address source; // rewards router
        address stakedGmx; // staked Gmx tracker
        address bonusGmx; // bonus Gmx tracker
        address feeGmx; // fee Gmx tracker
        address gmxVester; // Gmx vester rewards tracker
        address esGmx; // staked escrow gmx tracker

        address rewardReader; // rewards reader

        address[] nativeToWantRoute;

        // strategy params
        bool harvestOnDeposit;
        bool init;
    }

    function strategyStorage()
        internal
        pure
        returns (GmxStorageLayout storage aas)
    {
        bytes32 position = GMX_STORAGE_POSITION;
        assembly {
            aas.slot := position
        }
    }

    function init(
        GmxStorageLayout memory _initParams
        
    ) internal {
        require(msg.sender == LibDiamond.contractOwner(), "!owner");
        require(!strategyStorage().init, "Init already executed!");

        strategyStorage().source = _initParams.source;
        strategyStorage().stakedGmx = _initParams.stakedGmx;
        strategyStorage().bonusGmx = _initParams.bonusGmx;
        strategyStorage().feeGmx = _initParams.feeGmx;
        strategyStorage().gmxVester = _initParams.gmxVester;
        strategyStorage().esGmx = _initParams.esGmx;

        strategyStorage().rewardReader = _initParams.rewardReader;

        strategyStorage().nativeToWantRoute = _initParams.nativeToWantRoute;

        strategyStorage().harvestOnDeposit = _initParams.harvestOnDeposit;

        strategyStorage().init = true;
    }
}
