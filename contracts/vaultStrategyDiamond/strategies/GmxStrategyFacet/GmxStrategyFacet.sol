// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultStorage} from "../../storage/VaultStorage.sol";
import {GmxStrategyStorage} from "./storage/GmxStrategyStorage.sol";
import {IPinjamStrategy} from "../../interfaces/IPinjamStrategy.sol";
import {IUniswapRouterETH} from "../../interfaces/IUniswapRouterETH.sol";
import {IRewardRouter} from "./interfaces/IRewardRouter.sol";
import {IRewardReader} from "./interfaces/IRewardRouter.sol";
import {IUniswapRouterETH} from "../../interfaces/IUniswapRouterETH.sol";

contract GmxStrategyFacet is IPinjamStrategy {
    using SafeERC20 for IERC20;

    function init(
        GmxStrategyStorage.GmxStorageLayout memory _stratInit
    ) external {
        GmxStrategyStorage.init(
            _stratInit
        );

        IERC20(VaultStorage.vaultStorage().want).safeApprove(
            GmxStrategyStorage.strategyStorage().source,
            type(uint256).max
        );

        IERC20(VaultStorage.vaultStorage().want).safeApprove(
            GmxStrategyStorage.strategyStorage().stakedGmx,
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
    }

    function _beforeDeposit() internal override {
        if (GmxStrategyStorage.strategyStorage().harvestOnDeposit) {
            _harvest();
        }
    }

    function deposit(uint256 _amount) public override {
        _beforeDeposit();

        IRewardRouter(GmxStrategyStorage.strategyStorage().source).stakeGmx(
            _amount
        );

        emit Deposit(_amount);
    }

    function withdraw(
        address _to,
        uint256 _amount
    ) public override returns (uint256) {
        uint256 availBalance = balanceOfPool();

        if (availBalance == 0) return 0;

        if (_amount > availBalance) {
            _amount = availBalance;
        }

        IRewardRouter(GmxStrategyStorage.strategyStorage().source).unstakeGmx(
            _amount
        );

        IERC20(VaultStorage.vaultStorage().want).safeTransfer(_to, _amount);

        emit Withdraw(_to, _amount);

        return _amount;
    }

    function harvest() external override {
        _harvest();
    }

    function _harvest() internal override {
        IRewardRouter(GmxStrategyStorage.strategyStorage().source).compound();
        IRewardReader(GmxStrategyStorage.strategyStorage().feeGmx).claim(address(this));

        uint256 weth = IERC20(NATIVE_WRAPPED_TOKEN).balanceOf(address(this));

        // swaps weth to gmx
        if(weth > 0){
            uint256 swapped = _swapRewards(weth);
            deposit(swapped);
        }
    }

    // The sum of balanceOfPool, increases after harvest
    function balanceOf() public view override returns (uint256) {
        return balanceOfPool();
    }

    // Calculates how much want the strategy has working in the farm
    function balanceOfPool() internal view returns (uint256 balance_) {
        address[] memory tokens = new address[](1);
        tokens[0] = VaultStorage.vaultStorage().want;
        address[] memory rewardTrackers = new address[](1);
        rewardTrackers[0] = GmxStrategyStorage.strategyStorage().stakedGmx; // staked gmx balance

        uint256[] memory balances = IRewardReader(GmxStrategyStorage.strategyStorage().rewardReader).getDepositBalances(address(this), tokens, rewardTrackers);
 
        return balances[0];
    }

    // Pending fee rewards
    function pendingRewards() public view override returns (uint256[] memory) {
        uint256 feeGmxRewards = IRewardReader(GmxStrategyStorage.strategyStorage().feeGmx).claimable(address(this)); // in WAVAX
        uint256[] memory stakingRewards = new uint256[](1);

        stakingRewards[0] = feeGmxRewards;

        return stakingRewards; 
    }

    // swap rewards to {want}
    function _swapRewards(uint256 _nativeBalance) internal returns (uint256 rewards_){
        uint256[] memory outAmount = IUniswapRouterETH(UNISWAP_V2_ROUTER)
                .getAmountsOut(
                    _nativeBalance,
                    GmxStrategyStorage.strategyStorage().nativeToWantRoute
                );
        
        uint256 wantOutAmount = outAmount[outAmount.length - 1];
        if (wantOutAmount > 0) {
            uint256[] memory swapped = IUniswapRouterETH(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
                _nativeBalance,
                wantOutAmount,
                GmxStrategyStorage.strategyStorage().nativeToWantRoute,
                address(this),
                block.timestamp
            );
            rewards_ = swapped[1];
        }
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external override {
        GmxStrategyStorage
            .strategyStorage()
            .harvestOnDeposit = _harvestOnDeposit;
    }

    function getHarvestOnDeposit()
        external
        view
        override
        returns (bool harvestOnDeposit_)
    {
        harvestOnDeposit_ = GmxStrategyStorage
            .strategyStorage()
            .harvestOnDeposit;
    }

    function getStrategySource()
        external
        view
        override
        returns (address yieldSource_)
    {
        yieldSource_ = GmxStrategyStorage.strategyStorage().source;
    }
}
