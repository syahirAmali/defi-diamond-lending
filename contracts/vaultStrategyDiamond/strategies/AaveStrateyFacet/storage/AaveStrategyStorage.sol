// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {LibDiamond} from "../../../../libraries/LibDiamond.sol";

library AaveStrategyStorage {
    bytes32 private constant AAVE_STORAGE_POSITION =
        keccak256("diamond.standard.aaveStrategy.storage");

    struct AaveStorageLayout {
        // Tokens used
        address aToken;
        // Third party contracts
        address source;
        address[] nativeToWantRoute;
        bool harvestOnDeposit;
        bool init;
    }

    function strategyStorage()
        internal
        pure
        returns (AaveStorageLayout storage aas)
    {
        bytes32 position = AAVE_STORAGE_POSITION;
        assembly {
            aas.slot := position
        }
    }

    function init(
        AaveStorageLayout memory _initParams,
        address _native,
        address _want
    ) internal {
        require(msg.sender == LibDiamond.contractOwner(), "!owner");
        require(!strategyStorage().init, "Init already executed!");

        strategyStorage().source = _initParams.source;

        strategyStorage().harvestOnDeposit = _initParams.harvestOnDeposit;
        strategyStorage().aToken = _initParams.aToken;

        // TODO: Path should be coming externally, not hardcoded like this
        strategyStorage().nativeToWantRoute.push(_native);
        strategyStorage().nativeToWantRoute.push(_want);

        strategyStorage().init = true;
    }
}
