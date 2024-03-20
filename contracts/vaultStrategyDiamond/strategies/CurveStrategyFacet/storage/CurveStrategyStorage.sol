// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {LibDiamond} from "../../../../libraries/LibDiamond.sol";
import {IEquilibreRouter} from "../interfaces/IEquilibreRouter.sol";

library CurveStrategyStorage {
    bytes32 private constant STORAGE_POSITION =
        keccak256("diamond.standard.curve.storage");

    struct CurveExchangeStruct {
        int120 i;
        int120 j;
        bool enabled;
    }

    struct StrategyStorageLayout {
        address source;
        address callFeeRecipient;
        uint96 callFee;
        bool harvestOnDeposit;
        bool init;

        uint256 slippage;

        address curveTriAxlPool; 
        address curveTriAxlGauge;
        address triAxlLpToken;

        address axlDai;
        address axlUsdc;
        address axlUsdt;
        address wkava;

        uint128 wantTokenIndex;

        address[3] curvePoolTokens;

        address equilibreRouter;

        uint8 rewardToCurveLength;
        mapping(uint256 => IEquilibreRouter.route) rewardToCurveRoute;

        CurveExchangeStruct curveRewardToWantRoute;

        uint16 maxBP;
    }

    struct InitParams {
        address source;
        address callFeeRecipient;
        uint256 callFee;
        bool harvestOnDeposit;
        uint128 wantTokenIndex;
        bool init;
        IEquilibreRouter.route[] rewardToCurveRoute;

        address equilibreRouter;

        CurveExchangeStruct curveRewardToWantRoute;
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
        data.callFeeRecipient = _initParams.callFeeRecipient;
        data.callFee = uint96(_initParams.callFee);

        data.harvestOnDeposit = _initParams.harvestOnDeposit;

        data.slippage = 500;

        data.curveTriAxlPool = address(0x29C623E1Cc593864bB3E41E31a8f72ed262F38e5); 
        data.curveTriAxlGauge = address(0x8e10F4BACbB23885dB606370FC2B0A3298C01082);
        data.triAxlLpToken = address(0x29C623E1Cc593864bB3E41E31a8f72ed262F38e5);

        data.axlDai = address(0x5C7e299CF531eb66f2A1dF637d37AbB78e6200C7);
        data.axlUsdc = address(0xEB466342C4d449BC9f53A865D5Cb90586f405215);
        data.axlUsdt = address(0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6);

        data.curvePoolTokens = [data.axlDai, data.axlUsdc, data.axlUsdt];

        data.wkava = address(0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b);

        data.wantTokenIndex = _initParams.wantTokenIndex;

        data.equilibreRouter = _initParams.equilibreRouter;

        data.rewardToCurveLength = uint8(_initParams.rewardToCurveRoute.length);

        for(uint256 i; i < data.rewardToCurveLength; i++){
            data.rewardToCurveRoute[i] = _initParams.rewardToCurveRoute[i];
        }

        data.curveRewardToWantRoute = _initParams.curveRewardToWantRoute;

        data.maxBP = 10000;

        data.init = true;
    }
}
