// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultStorage} from "../../storage/VaultStorage.sol";
import {MareV2StrategyStorage} from "./storage/MareV2StrategyStorage.sol";
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

    function getExternalRewardDistributorAddress()
        external
        view
        returns (address);

    // function rewardsAccrued(address holder) external view returns (uint256);

    function rewardsAccrued(
        address comptroller,
        address holder
    )
        external
        view
        returns (address[] memory rewadTokens, uint256[] memory accrued);
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

contract MareV2StrategyFacet is IPinjamStrategy {
    using SafeERC20 for IERC20;

    address public constant MARE_TOKEN =
        0xd86C8d4279CCaFbec840c782BcC50D201f277419;
    address public constant MULTI_USDC =
        0xfA9343C3897324496A05fC75abeD6bAC29f8A40f;
    address public constant COMPOUND_COMPTROLLER =
        0xFcD7D41D5cfF03C7f6D573c9732B0506C72f5C72;
    IMareExternalRewardDistributor
        public constant MARE_EXTERNAL_REWARD_DISTRIBUTOR =
        IMareExternalRewardDistributor(
            0xA0c8385fDbD7E5ce1cEcEf0a461B487C91658604
        );

    address public constant KAVA_3_POOL =
        0x7A0e3b70b1dB0D6CA63Cac240895b2D21444A7b9;

    function deposit(uint256 _amount) public override {
        _beforeDeposit();
        IcToken(MareV2StrategyStorage.strategyStorage().source).mint(_amount);

        emit Deposit(_amount);
    }

    function withdraw(
        address,
        uint256 _amount
    ) public override returns (uint256) {
        (, uint256 internalBalance, , uint256 exchangeRate) = IcToken(
            MareV2StrategyStorage.strategyStorage().source
        ).getAccountSnapshot(address(this));

        // redeem is actually done with qiToken amounts and not the conversion of it
        // + 1 to act as buffer for rounding errors
        uint256 cBalanceRedeemAmount = 1 +
            ((_amount * 10 ** 18) / exchangeRate);

        if (cBalanceRedeemAmount > internalBalance) {
            cBalanceRedeemAmount = internalBalance;
        }

        IcToken(MareV2StrategyStorage.strategyStorage().source).redeem(
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
    function init(MareV2StrategyStorage.InitParams memory _stratInit) public {
        {
            MareV2StrategyStorage.init(_stratInit);
        }
        IERC20(VaultStorage.vaultStorage().want).safeApprove(
            MareV2StrategyStorage.strategyStorage().source,
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

        if (
            IERC20(MARE_TOKEN).allowance(address(this), UNISWAP_V2_ROUTER) == 0
        ) {
            IERC20(MARE_TOKEN).safeApprove(
                UNISWAP_V2_ROUTER,
                type(uint256).max
            );
        }
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external override {
        MareV2StrategyStorage
            .strategyStorage()
            .harvestOnDeposit = _harvestOnDeposit;
    }

    function setCallFeeRecepient(address _callFeeRecipient) external {
        MareV2StrategyStorage
            .strategyStorage()
            .callFeeRecipient = _callFeeRecipient;
    }

    function setSlippage(uint256 _slippage) external {
        require(_slippage <= 5000, "Slippage cannot be greater than 50%");
        MareV2StrategyStorage.strategyStorage().slippage = uint16(_slippage);
    }

    function getSlippage() external view returns (uint256) {
        return MareV2StrategyStorage.strategyStorage().slippage;
    }

    function getCallFeeRecepient() external view returns (address) {
        return MareV2StrategyStorage.strategyStorage().callFeeRecipient;
    }

    /** VIEW ONLY */
    // The total balance working in Compound
    function balanceOf() public view override returns (uint256) {
        (, uint256 internalBalance, , uint256 exchangeRate) = IcToken(
            MareV2StrategyStorage.strategyStorage().source
        ).getAccountSnapshot(address(this));

        if (internalBalance == 0 || exchangeRate == 0) return 0;

        return (internalBalance * exchangeRate) / 1e18;
    }

    function pendingRewards() public view override returns (uint256[] memory) {
        uint256[] memory balance = new uint256[](3);
        // mare rewards
        balance[0] = MARE_EXTERNAL_REWARD_DISTRIBUTOR
            .rewardAccountState(MARE_TOKEN, address(this))
            .rewardAccrued;

        // kava rewards
        balance[1] = MARE_EXTERNAL_REWARD_DISTRIBUTOR
            .rewardAccountState(NATIVE_WRAPPED_TOKEN, address(this))
            .rewardAccrued;

        // multiUsdc rewards
        balance[2] = MARE_EXTERNAL_REWARD_DISTRIBUTOR
            .rewardAccountState(MULTI_USDC, address(this))
            .rewardAccrued;

        return balance;
    }

    function getHarvestOnDeposit()
        external
        view
        override
        returns (bool _harvestOnDeposit)
    {
        _harvestOnDeposit = MareV2StrategyStorage
            .strategyStorage()
            .harvestOnDeposit;
    }

    function getStrategySource()
        external
        view
        override
        returns (address yieldSource_)
    {
        yieldSource_ = MareV2StrategyStorage.strategyStorage().source;
    }

    /** INTERNAL FUNCTIONS */

    function _harvest() internal override {
        MareV2StrategyStorage.StrategyStorageLayout
            storage _storage = MareV2StrategyStorage.strategyStorage();

        IcToken[] memory ictokens = new IcToken[](1);
        ictokens[0] = IcToken(_storage.source);

        address[] memory holders = new address[](1);
        holders[0] = payable(address(this));

        IComptroller(COMPOUND_COMPTROLLER).claimComp(
            holders,
            ictokens,
            false,
            true
        );

        uint256 mareBalance = IERC20(MARE_TOKEN).balanceOf(address(this));
        if (mareBalance > 0) {
            uint256 callFee = (mareBalance * _storage.callFee) / MAX_BP;
            IERC20(MARE_TOKEN).transfer(_storage.callFeeRecipient, callFee);

            _swapMareRewards(mareBalance - callFee, _storage);
        }

        if (!_storage.isNativeStrategy) {
            uint256 nativeBal = IERC20(NATIVE_WRAPPED_TOKEN).balanceOf(
                address(this)
            );

            if (nativeBal > 0) {
                uint256 nativeCallFee = (nativeBal * _storage.callFee) / MAX_BP;

                IERC20(NATIVE_WRAPPED_TOKEN).transfer(
                    _storage.callFeeRecipient,
                    nativeCallFee
                );
                _swapKavaRewards(nativeBal - nativeCallFee, _storage);
            }
        }

        uint256 multiUsdcBalance = IERC20(MULTI_USDC).balanceOf(address(this));

        if (multiUsdcBalance > 0) {
            uint256 multiUsdcCallFee = (multiUsdcBalance * _storage.callFee) /
                MAX_BP;
            IERC20(MULTI_USDC).transfer(
                _storage.callFeeRecipient,
                multiUsdcCallFee
            );
            _swapUsdcRewards(multiUsdcBalance - multiUsdcCallFee, _storage);
        }
    }

    // swap rewards to {want}
    function _swapMareRewards(
        uint256 _qiBalance,
        MareV2StrategyStorage.StrategyStorageLayout storage _storage
    ) internal {
        uint8 mareToWantRouteSize = uint8(_storage.mareToWantRoute.length);
        if (mareToWantRouteSize == 0) return;
        // swaps mare to want
        IEquilibreRouter.route[]
            memory routeTuple = new IEquilibreRouter.route[](
                mareToWantRouteSize
            );

        for (uint256 i; i < mareToWantRouteSize; i++) {
            routeTuple[i] = _storage.mareToWantRoute[i];
        }

        uint256[] memory outAmounts = IEquilibreRouter(UNISWAP_V2_ROUTER)
            .swapExactTokensForTokens(
                _qiBalance,
                0,
                routeTuple,
                address(this),
                block.timestamp
            );

        require(
            outAmounts[outAmounts.length - 1] > 0,
            "mareSwap: insufficient output amount"
        );
    }

    function _swapKavaRewards(
        uint256 _nativeBalance,
        MareV2StrategyStorage.StrategyStorageLayout storage _storage
    ) internal {
        uint8 nativeToWantRouteSize = uint8(_storage.nativeToWantRoute.length);
        if (nativeToWantRouteSize == 0) return;

        // swaps mare to want
        IEquilibreRouter.route[]
            memory routeTuple = new IEquilibreRouter.route[](
                nativeToWantRouteSize
            );

        for (uint256 i; i < nativeToWantRouteSize; i++) {
            routeTuple[i] = _storage.nativeToWantRoute[i];
        }

        uint256[] memory outAmounts = IEquilibreRouter(UNISWAP_V2_ROUTER)
            .swapExactTokensForTokens(
                _nativeBalance,
                0,
                routeTuple,
                address(this),
                block.timestamp
            );

        require(
            outAmounts[outAmounts.length - 1] > 0,
            "nativeSwap: insufficient output amount"
        );
    }

    function _swapUsdcRewards(
        uint256 _usdcBalance,
        MareV2StrategyStorage.StrategyStorageLayout storage _storage
    ) internal {
        uint8 nativeToWantRouteSize = uint8(
            _storage.multiUsdcToWantRoute.length
        );
        if (nativeToWantRouteSize == 0) return;

        // swaps mare to want
        IEquilibreRouter.route[]
            memory routeTuple = new IEquilibreRouter.route[](
                nativeToWantRouteSize
            );

        for (uint256 i; i < nativeToWantRouteSize; i++) {
            routeTuple[i] = _storage.multiUsdcToWantRoute[i];
        }

        uint256[] memory outAmounts = IEquilibreRouter(UNISWAP_V2_ROUTER)
            .swapExactTokensForTokens(
                _usdcBalance,
                0,
                _storage.multiUsdcToWantRoute,
                address(this),
                block.timestamp
            );

        require(
            outAmounts[outAmounts.length - 1] > 0,
            "multiUsdcSwap: insufficient output amount"
        );
    }

    function _beforeDeposit() internal override {
        if (MareV2StrategyStorage.strategyStorage().harvestOnDeposit) {
            _harvest();
        }
    }
}
