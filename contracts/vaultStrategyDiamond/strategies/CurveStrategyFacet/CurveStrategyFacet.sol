// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultStorage} from "../../storage/VaultStorage.sol";
import {CurveStrategyStorage} from "./storage/CurveStrategyStorage.sol";
import {IPinjamStrategy} from "./interfaces/IPinjamStrategy.sol";
import {ICurvePool} from "./interfaces/ICurvePool.sol";
import {ICurveGauge} from "./interfaces/ICurveGauge.sol";
import {IEquilibreRouter} from "./interfaces/IEquilibreRouter.sol";
import {IEquilibrePair} from "./interfaces/IEquilibrePair.sol";

contract CurveStrategyFacet is IPinjamStrategy {
    using SafeERC20 for IERC20;

    function deposit(uint256 _amount) public override {
        _beforeDeposit();

        CurveStrategyStorage.StrategyStorageLayout storage curveStorage = CurveStrategyStorage.strategyStorage();

        uint256[] memory balance = new uint256[](3);

        // get amounts to add to curve pool as liquidity
        for(uint8 i; i < curveStorage.curvePoolTokens.length; i++){
            balance[i] = IERC20(curveStorage.curvePoolTokens[i]).balanceOf(address(this));
            if(balance[i] > 0){
                IERC20(curveStorage.curvePoolTokens[i]).safeApprove(address(curveStorage.curveTriAxlPool), balance[i]);
            }
        }

        // 01 - deposit stable coins in this case tether usdt to get curve lp tokens
        ICurvePool(curveStorage.curveTriAxlPool).add_liquidity(balance, 0);

        // 02 - get lp token balance
        uint256 lpBalance = IERC20(curveStorage.triAxlLpToken).balanceOf(address(this));

        // 03 - stake curve lp tokens into gauge to get crv rewards
        _depositLp(lpBalance, curveStorage);

        emit Deposit(_amount);
    }

    function _depositLp(uint256 _lpAmount, CurveStrategyStorage.StrategyStorageLayout storage _s) internal {
        IERC20(_s.triAxlLpToken).approve(address(_s.curveTriAxlGauge), _lpAmount);
        ICurveGauge(_s.curveTriAxlGauge).deposit(_lpAmount);
    }

    function withdraw(
        address,
        uint256 _amount
    ) public override returns (uint256) {
        CurveStrategyStorage.StrategyStorageLayout storage curveStorage = CurveStrategyStorage.strategyStorage();

        uint256 sharesToWithdraw = (_amount * 10**18) / _getVirtualPrice(curveStorage);

        // 01 - withdraws the lp tokens from the gauge
        ICurveGauge(curveStorage.curveTriAxlGauge).withdraw(sharesToWithdraw);

        // 02 - removes liquidity from the curve pool according to the amount of tokens we want to withdraw
        IERC20(curveStorage.triAxlLpToken).approve(address(curveStorage.curveTriAxlPool), sharesToWithdraw);

        
        uint256 minAmountOut = _calcWithdrawOneCoin(sharesToWithdraw, curveStorage.wantTokenIndex, curveStorage);
        ICurvePool(curveStorage.curveTriAxlPool).remove_liquidity_one_coin(sharesToWithdraw, curveStorage.wantTokenIndex, minAmountOut);


        emit Withdraw(address(this), _amount);

        // Returns 0 because cToken will withdraw to vault instead of directly to _to
        return 0;
    }

    // function _withdrawLp(uint256 _lpAmount) internal {
    //     ICurveGauge(curveTriAxlGauge).withdraw(_lpAmount);
    // }

    function _calcWithdrawOneCoin(uint256 _shares, uint128 _index, CurveStrategyStorage.StrategyStorageLayout storage _s) internal returns(uint256) {
        return ICurvePool(_s.curveTriAxlPool).calc_withdraw_one_coin(_shares, _index);
    }

    function _getLpShares(CurveStrategyStorage.StrategyStorageLayout storage _s) internal view returns(uint256) {
        return IERC20(_s.triAxlLpToken).balanceOf(address(this));
    }

    function _getVirtualPrice(CurveStrategyStorage.StrategyStorageLayout storage _s) internal view returns(uint256) {
        return ICurvePool(_s.curveTriAxlPool).get_virtual_price();
    }

    function harvest() external override {
        _harvest();
    }

    /** ADMIN ONLY */
    function init(CurveStrategyStorage.InitParams memory _stratInit) external {
        CurveStrategyStorage.init(_stratInit);
            CurveStrategyStorage.StrategyStorageLayout storage curveStorage = CurveStrategyStorage.strategyStorage();

        IERC20(VaultStorage.vaultStorage().want).safeApprove(
            CurveStrategyStorage.strategyStorage().source,
            type(uint256).max
        );

        if (
            IERC20(curveStorage.wkava).allowance(
                address(this),
                curveStorage.equilibreRouter
            ) == 0
        ) {
            IERC20(curveStorage.wkava).safeApprove(
                curveStorage.equilibreRouter,
                type(uint256).max
            );
        }

        
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external override {
        CurveStrategyStorage
            .strategyStorage()
            .harvestOnDeposit = _harvestOnDeposit;
    }

    function setCallFeeRecepient(address _callFeeRecipient) external {
        CurveStrategyStorage
            .strategyStorage()
            .callFeeRecipient = _callFeeRecipient;
    }

    function setSlippage(uint256 _slippage) external {
        CurveStrategyStorage.strategyStorage().slippage = _slippage;
    }

    function getSlippage() external view returns (uint256) {
        return CurveStrategyStorage.strategyStorage().slippage;
    }

    function getCallFeeRecepient() external view returns (address) {
        return CurveStrategyStorage.strategyStorage().callFeeRecipient;
    }

    /** VIEW ONLY */
    // The total balance working in Curve
    function balanceOf() public view override returns (uint256) {
        CurveStrategyStorage.StrategyStorageLayout storage curveStorage = CurveStrategyStorage.strategyStorage();

        return IERC20(curveStorage.triAxlLpToken).balanceOf(address(this));
    }
    

    function pendingRewards() public view override returns (uint256[] memory) {
        CurveStrategyStorage.StrategyStorageLayout storage curveStorage = CurveStrategyStorage.strategyStorage();

        uint256[] memory balance = new uint256[](2);

        balance[0] = ICurveGauge(curveStorage.curveTriAxlGauge).claimable_reward(address(this), curveStorage.wkava);

        return balance;
    }

    function getHarvestOnDeposit()
        external
        view
        override
        returns (bool _harvestOnDeposit)
    {
        _harvestOnDeposit = CurveStrategyStorage
            .strategyStorage()
            .harvestOnDeposit;
    }

    function getStrategySource()
        external
        view
        override
        returns (address yieldSource_)
    {
        yieldSource_ = CurveStrategyStorage.strategyStorage().source;
    }

    /** INTERNAL FUNCTIONS */

    function _harvest() internal override {
        CurveStrategyStorage.StrategyStorageLayout storage curveStorage = CurveStrategyStorage.strategyStorage();

        ICurveGauge(curveStorage.curveTriAxlGauge).claim_rewards();

        uint256 balance = IERC20(curveStorage.wkava).balanceOf(address(this));

        if(balance > 0){
            _swapKavaRewards(balance, curveStorage);
        }
    }

    function _swapKavaRewards(uint256 _balance, CurveStrategyStorage.StrategyStorageLayout storage _s) internal {

        IEquilibreRouter.route[] memory route = new IEquilibreRouter.route[](
            _s.rewardToCurveLength
        );

        for(uint256 i; i < _s.rewardToCurveLength; i++){
            route[i] = _s.rewardToCurveRoute[i];
        }

        address pair = IEquilibreRouter(_s.equilibreRouter).pairFor(
            route[0].from,
            route[0].to,
            route[0].stable
        );

        uint256 minAmountOut = IEquilibrePair(pair).current(
            route[0].from,
            _balance
        );

        minAmountOut = (minAmountOut * (_s.maxBP - _s.slippage)) /
            _s.maxBP;
        
        if(minAmountOut == 0){
            return;
        }

        uint256[] memory outAmounts = IEquilibreRouter(_s.equilibreRouter)
            .swapExactTokensForTokens(
                _balance,
                minAmountOut,
                route,
                address(this),
                block.timestamp
            );

        uint256 inAmount = outAmounts[outAmounts.length - 1];

        if(inAmount < 0){
            return;
        }

        uint256 curveWantOutAmount = ICurvePool(_s.curveTriAxlPool).get_dy(
            _s.curveRewardToWantRoute.i,
            _s.curveRewardToWantRoute.j,
            inAmount
        );

        ICurvePool(_s.curveTriAxlPool).exchange(
            _s.curveRewardToWantRoute.i,
            _s.curveRewardToWantRoute.j,
            inAmount,
            curveWantOutAmount
        );
    }

    function _beforeDeposit() internal override {
        if (CurveStrategyStorage.strategyStorage().harvestOnDeposit) {
            _harvest();
        }
    }
}
