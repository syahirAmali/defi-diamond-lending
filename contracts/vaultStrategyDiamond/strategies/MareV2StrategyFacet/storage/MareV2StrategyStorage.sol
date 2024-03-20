// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {LibDiamond} from "../../../../libraries/LibDiamond.sol";
import {IEquilibreRouter} from "../interfaces/IEquilibreRouter.sol";

library MareV2StrategyStorage {
    bytes32 private constant STORAGE_POSITION =
        keccak256("diamond.standard.marev2.storage");

    struct StrategyStorageLayout {
        address source;
        address callFeeRecipient;
        IEquilibreRouter.route[] mareToWantRoute;
        IEquilibreRouter.route[] nativeToWantRoute;
        IEquilibreRouter.route[] multiUsdcToWantRoute;
        uint96 callFee;
        uint16 slippage;
        bool harvestOnDeposit;
        bool init;
        bool isNativeStrategy;
    }

    struct InitParams {
        uint256 callFee;
        address source;
        address callFeeRecipient;
        bool harvestOnDeposit;
        bool init;
        bool isNativeStrategy;
        IEquilibreRouter.route[] mareToWantRoute;
        IEquilibreRouter.route[] nativeToWantRoute;
        IEquilibreRouter.route[] multiUsdcToWantRoute;
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

    function init(InitParams memory _initParams) internal {
        require(msg.sender == LibDiamond.contractOwner(), "!owner");
        StrategyStorageLayout storage data = strategyStorage();

        require(!data.init, "Init already executed!");

        data.source = _initParams.source;
        data.harvestOnDeposit = _initParams.harvestOnDeposit;
        data.callFee = uint96(_initParams.callFee);
        data.callFeeRecipient = _initParams.callFeeRecipient;

        data.isNativeStrategy = _initParams.isNativeStrategy;

        for (uint256 i = 0; i < _initParams.mareToWantRoute.length; i++) {
            data.mareToWantRoute.push(_initParams.mareToWantRoute[i]);
        }

        for (uint256 i = 0; i < _initParams.nativeToWantRoute.length; i++) {
            data.nativeToWantRoute.push(_initParams.nativeToWantRoute[i]);
        }

        for (uint256 i = 0; i < _initParams.multiUsdcToWantRoute.length; i++) {
            data.multiUsdcToWantRoute.push(_initParams.multiUsdcToWantRoute[i]);
        }

        data.slippage = 750;
        data.init = true;
    }
}
