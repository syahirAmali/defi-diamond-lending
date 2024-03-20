// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {LibDiamond} from "../../../../libraries/LibDiamond.sol";
import {IEquilibreRouter} from "../interfaces/IEquilibreRouter.sol";

library MareStrategyStorage {
    uint256 public constant SLIPPAGE = 100;

    bytes32 private constant STORAGE_POSITION =
        keccak256("diamond.standard.compound.storage");

    struct CurveExchangeStruct {
        int120 i;
        int120 j;
        bool enabled;
    }

    struct StrategyStorageLayout {
        address source;
        address callFeeRecipient;
        mapping(uint256 => IEquilibreRouter.route) mareToWantRoute;
        CurveExchangeStruct curveMareToWantRoute;
        mapping(uint256 => IEquilibreRouter.route) nativeToWantRoute;
        CurveExchangeStruct curveNativeToWantRoute;
        uint96 callFee;
        uint8 mareToWantRouteSize;
        uint8 nativeToWantRouteSize;
        bool harvestOnDeposit;
        bool init;
        bool isNativeStrategy;

        uint256 slippage;
    }

    struct InitParams {
        uint256 callFee;
        address source;
        address callFeeRecipient;
        bool harvestOnDeposit;
        bool init;
        bool isNativeStrategy;
        IEquilibreRouter.route[] mareToWantRoute;
        CurveExchangeStruct curveMareToWantRoute;
        IEquilibreRouter.route[] nativeToWantRoute;
        CurveExchangeStruct curveNativeToWantRoute;
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
        data.mareToWantRouteSize = uint8(_initParams.mareToWantRoute.length);
        data.curveMareToWantRoute = _initParams.curveMareToWantRoute;
        data.callFee = uint96(_initParams.callFee);
        data.callFeeRecipient = _initParams.callFeeRecipient;

        data.nativeToWantRouteSize = uint8(
            _initParams.nativeToWantRoute.length
        );
        data.curveNativeToWantRoute = _initParams.curveNativeToWantRoute;
        data.isNativeStrategy = _initParams.isNativeStrategy;

        for (uint256 i; i < data.mareToWantRouteSize; i++) {
            data.mareToWantRoute[i] = _initParams.mareToWantRoute[i];
        }

        for (uint256 i; i < data.nativeToWantRouteSize; i++) {
            data.nativeToWantRoute[i] = _initParams.nativeToWantRoute[i];
        }

        data.slippage = 500;

        data.init = true;
    }
}
