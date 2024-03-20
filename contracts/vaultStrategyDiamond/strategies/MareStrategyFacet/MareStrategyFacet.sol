// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultStorage} from "../../storage/VaultStorage.sol";
import {MareStrategyStorage} from "./storage/MareStrategyStorage.sol";
import {IPinjamStrategy} from "../../interfaces/IPinjamStrategy.sol";
import {IEquilibreRouter} from "./interfaces/IEquilibreRouter.sol";
import {IEquilibrePair} from "./interfaces/IEquilibrePair.sol";

interface ICurveFinance {
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);

    function get_dy(int128 i, int128 j, uint256 dx) external returns (uint256);
}

interface IcToken {
    function mint(uint256 mintAmount) external returns (uint256);

    function mint() external payable;

    function redeem(uint256 redeemAmount) external;

    function balanceOfUnderlying(address account) external returns (uint256);

    function getAccountSnapshot(
        address account
    )
        external
        view
        returns (
            uint256 error,
            uint256 balance,
            uint256 borrow,
            uint256 mantissa
        );

    function balanceOf(address account) external view returns (uint256);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function exchangeRateCurrent() external view returns (uint256);
}

interface IComptroller {
    function claimComp(
        address[] memory holders,
        IcToken[] memory mareTokens,
        bool borrowers,
        bool suppliers
    ) external;

    function compAccrued(address holder) external view returns (uint256);

    function isComptroller() external view returns (bool);
}

interface IMareExternalRewardDistributor {
    struct RewardAccountState {
        /// @notice Accrued Reward but not yet transferred
        uint256 rewardAccrued;
    }

    function rewardAccountState(
        address rewardToken,
        address receiver
    ) external view returns (RewardAccountState memory);
}

contract MareStrategyFacet is IPinjamStrategy {
    using SafeERC20 for IERC20;

    address public constant MARE_TOKEN =
        0xd86C8d4279CCaFbec840c782BcC50D201f277419;
    address public constant COMPOUND_COMPTROLLER =
        0x4804357AcE69330524ceb18F2A647c3c162E1F95;
    IMareExternalRewardDistributor
        public constant MARE_EXTERNAL_REWARD_DISTRIBUTOR =
        IMareExternalRewardDistributor(
            0xa02B2b868B118920990D7BC0fFA9468E44e34663
        );

    address public constant KAVA_3_POOL =
        0x7A0e3b70b1dB0D6CA63Cac240895b2D21444A7b9;

    function deposit(uint256 _amount) public override {
        _beforeDeposit();
        IcToken(MareStrategyStorage.strategyStorage().source).mint(_amount);

        emit Deposit(_amount);
    }

    function withdraw(
        address,
        uint256 _amount
    ) public override returns (uint256) {
        (, uint256 internalBalance, , uint256 exchangeRate) = IcToken(
            MareStrategyStorage.strategyStorage().source
        ).getAccountSnapshot(address(this));

        // redeem is actually done with qiToken amounts and not the conversion of it
        // + 1 to act as buffer for rounding errors
        uint256 cBalanceRedeemAmount = 1 +
            ((_amount * 10 ** 18) / exchangeRate);

        if (cBalanceRedeemAmount > internalBalance) {
            cBalanceRedeemAmount = internalBalance;
        }

        IcToken(MareStrategyStorage.strategyStorage().source).redeem(
            cBalanceRedeemAmount
        );

        emit Withdraw(address(this), cBalanceRedeemAmount);

        // Returns 0 because cToken will withdraw to vault instead of directly to _to
        return 0;
    }

    function harvest() external override {
        _harvest();
    }

    /** ADMIN ONLY */
    function init(MareStrategyStorage.InitParams memory _stratInit) external {
        MareStrategyStorage.init(_stratInit);

        IERC20(VaultStorage.vaultStorage().want).safeApprove(
            MareStrategyStorage.strategyStorage().source,
            type(uint256).max
        );

        if (
            IERC20(NATIVE_WRAPPED_TOKEN).allowance(
                address(this),
                UNISWAP_V2_ROUTER
            ) == 0
        ) {
            IERC20(NATIVE_WRAPPED_TOKEN).safeApprove(
                UNISWAP_V2_ROUTER,
                type(uint256).max
            );
        }

        IERC20(MARE_TOKEN).safeApprove(UNISWAP_V2_ROUTER, type(uint256).max);

        // If we are using curve routes at all, we need to approve the multi usdc address
        if (
            _stratInit.curveMareToWantRoute.enabled ||
            _stratInit.curveNativeToWantRoute.enabled
        ) {
            IERC20(MULTI_USDC_ADDRESS).safeApprove(
                KAVA_3_POOL,
                type(uint256).max
            );
        }
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external override {
        MareStrategyStorage
            .strategyStorage()
            .harvestOnDeposit = _harvestOnDeposit;
    }

    function setCallFeeRecepient(address _callFeeRecipient) external {
        MareStrategyStorage
            .strategyStorage()
            .callFeeRecipient = _callFeeRecipient;
    }

    function setSlippage(uint256 _slippage) external {
        MareStrategyStorage.strategyStorage().slippage = _slippage;
    }

    function getSlippage() external view returns (uint256) {
        return MareStrategyStorage.strategyStorage().slippage;
    }

    function getCallFeeRecepient() external view returns (address) {
        return MareStrategyStorage.strategyStorage().callFeeRecipient;
    }

    /** VIEW ONLY */
    // The total balance working in Compound
    function balanceOf() public view override returns (uint256) {
        (, uint256 internalBalance, , uint256 exchangeRate) = IcToken(
            MareStrategyStorage.strategyStorage().source
        ).getAccountSnapshot(address(this));

        if (internalBalance == 0 || exchangeRate == 0) return 0;

        return (internalBalance * exchangeRate) / 1e18;
    }

    function pendingRewards() public view override returns (uint256[] memory) {
        uint256[] memory balance = new uint256[](2);

        // mare rewards
        balance[0] = IComptroller(COMPOUND_COMPTROLLER).compAccrued(
            address(this)
        );

        // kava rewards
        balance[1] = MARE_EXTERNAL_REWARD_DISTRIBUTOR
            .rewardAccountState(NATIVE_WRAPPED_TOKEN, address(this))
            .rewardAccrued;

        return balance;
    }

    function getHarvestOnDeposit()
        external
        view
        override
        returns (bool _harvestOnDeposit)
    {
        _harvestOnDeposit = MareStrategyStorage
            .strategyStorage()
            .harvestOnDeposit;
    }

    function getStrategySource()
        external
        view
        override
        returns (address yieldSource_)
    {
        yieldSource_ = MareStrategyStorage.strategyStorage().source;
    }

    /** INTERNAL FUNCTIONS */

    function _harvest() internal override {
        MareStrategyStorage.StrategyStorageLayout
            storage _storage = MareStrategyStorage.strategyStorage();

        IcToken[] memory ictokens = new IcToken[](1);
        ictokens[0] = IcToken(_storage.source);

        address[] memory holders = new address[](1);
        holders[0] = payable(address(this));

        // 0 for mare
        IComptroller(COMPOUND_COMPTROLLER).claimComp(
            holders,
            ictokens,
            false,
            true
        );

        uint256 qiBalance = IERC20(MARE_TOKEN).balanceOf(address(this));
        uint256 callFee = (qiBalance * _storage.callFee) / MAX_BP;
        IERC20(MARE_TOKEN).transfer(_storage.callFeeRecipient, callFee);

        _swapMareRewards(qiBalance - callFee, _storage);

        if (!_storage.isNativeStrategy) {
            uint256 nativeBal = IERC20(NATIVE_WRAPPED_TOKEN).balanceOf(
                address(this)
            );
            uint256 nativeCallFee = (nativeBal * _storage.callFee) / MAX_BP;

            IERC20(NATIVE_WRAPPED_TOKEN).transfer(
                _storage.callFeeRecipient,
                nativeCallFee
            );
            _swapKavaRewards(nativeBal - nativeCallFee, _storage);
        }
    }

    // swap rewards to {want}
    function _swapMareRewards(
        uint256 _qiBalance,
        MareStrategyStorage.StrategyStorageLayout storage _storage
    ) internal {
        if (_qiBalance == 0) {
            return;
        }

        // swaps mare to want
        IEquilibreRouter.route[]
            memory routeTuple = new IEquilibreRouter.route[](
                _storage.mareToWantRouteSize
            );

        for (uint256 i; i < _storage.mareToWantRouteSize; i++) {
            routeTuple[i] = MareStrategyStorage
                .strategyStorage()
                .mareToWantRoute[i];
        }

        address pair = IEquilibreRouter(UNISWAP_V2_ROUTER).pairFor(
            routeTuple[0].from,
            routeTuple[0].to,
            routeTuple[0].stable
        );

        uint256 minAmountOut = IEquilibrePair(pair).current(
            routeTuple[0].from,
            _qiBalance
        );

        minAmountOut =
            (minAmountOut * (MAX_BP - _storage.slippage)) /
            MAX_BP;

        if (minAmountOut == 0) {
            return;
        }

        uint256[] memory outAmounts = IEquilibreRouter(UNISWAP_V2_ROUTER)
            .swapExactTokensForTokens(
                _qiBalance,
                minAmountOut,
                routeTuple,
                address(this),
                block.timestamp
            );

        MareStrategyStorage.CurveExchangeStruct
            memory curveMareToWantRoute = _storage.curveMareToWantRoute;

        if (!curveMareToWantRoute.enabled) {
            return;
        }
        uint256 inAmount = outAmounts[outAmounts.length - 1];

        uint256 curveWantOutAmount = ICurveFinance(KAVA_3_POOL).get_dy(
            curveMareToWantRoute.i,
            curveMareToWantRoute.j,
            inAmount
        );

        ICurveFinance(KAVA_3_POOL).exchange(
            curveMareToWantRoute.i,
            curveMareToWantRoute.j,
            inAmount,
            curveWantOutAmount
        );
    }

    function _swapKavaRewards(
        uint256 _nativeBalance,
        MareStrategyStorage.StrategyStorageLayout storage _storage
    ) internal {
        if (_nativeBalance == 0) {
            return;
        }

        // swaps mare to want
        IEquilibreRouter.route[]
            memory routeTuple = new IEquilibreRouter.route[](
                _storage.nativeToWantRouteSize
            );

        for (uint256 i; i < _storage.nativeToWantRouteSize; i++) {
            routeTuple[i] = _storage.nativeToWantRoute[i];
        }

        address pair = IEquilibreRouter(UNISWAP_V2_ROUTER).pairFor(
            routeTuple[0].from,
            routeTuple[0].to,
            routeTuple[0].stable
        );

        uint256 minAmountOut = IEquilibrePair(pair).current(
            routeTuple[0].from,
            _nativeBalance
        );

        minAmountOut =
            (minAmountOut * (MAX_BP - _storage.slippage)) /
            MAX_BP;

        if (minAmountOut == 0) {
            return;
        }

        uint256[] memory outAmounts = IEquilibreRouter(UNISWAP_V2_ROUTER)
            .swapExactTokensForTokens(
                _nativeBalance,
                minAmountOut,
                routeTuple,
                address(this),
                block.timestamp
            );

        MareStrategyStorage.CurveExchangeStruct
            memory curveNativeToWantRoute = _storage.curveNativeToWantRoute;

        if (!curveNativeToWantRoute.enabled) {
            return;
        }

        uint256 inAmount = outAmounts[outAmounts.length - 1];
        uint256 curveWantOutAmount = ICurveFinance(KAVA_3_POOL).get_dy(
            curveNativeToWantRoute.i,
            curveNativeToWantRoute.j,
            inAmount
        );

        ICurveFinance(KAVA_3_POOL).exchange(
            curveNativeToWantRoute.i,
            curveNativeToWantRoute.j,
            inAmount,
            curveWantOutAmount
        );
    }

    function _beforeDeposit() internal override {
        if (MareStrategyStorage.strategyStorage().harvestOnDeposit) {
            _harvest();
        }
    }
}
