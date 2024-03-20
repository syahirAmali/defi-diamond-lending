// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultStorage} from "../../storage/VaultStorage.sol";
import {AaveStrategyStorage} from "./storage/AaveStrategyStorage.sol";
import {IPinjamStrategy} from "../../interfaces/IPinjamStrategy.sol";
import {IUniswapRouterETH} from "../../interfaces/IUniswapRouterETH.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IAaveV3Incentives} from "./interfaces/IAaveV3Incentives.sol";

contract AaveStrategyFacet is IPinjamStrategy {
    using SafeERC20 for IERC20;

    address public constant AAVE_INCENTIVES_CONTROLLER =
        0x929EC64c34a17401F460460D4B9390518E5B473e;

    uint256 public constant BORROW_DEPTH_MAX = 10;

    function init(
        AaveStrategyStorage.AaveStorageLayout memory _stratInit
    ) external {
        AaveStrategyStorage.init(
            _stratInit,
            NATIVE_WRAPPED_TOKEN,
            VaultStorage.vaultStorage().want
        );

        IERC20(VaultStorage.vaultStorage().want).safeApprove(
            AaveStrategyStorage.strategyStorage().source,
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
        if (AaveStrategyStorage.strategyStorage().harvestOnDeposit) {
            _harvest();
        }
    }

    function deposit(uint256 _amount) public override {
        _beforeDeposit();
        ILendingPool(AaveStrategyStorage.strategyStorage().source).deposit(
            VaultStorage.vaultStorage().want,
            _amount,
            address(this),
            0
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

        ILendingPool(AaveStrategyStorage.strategyStorage().source).withdraw(
            VaultStorage.vaultStorage().want,
            _amount,
            _to
        );

        emit Withdraw(_to, _amount);
        return _amount;
    }

    function harvest() external override {
        _harvest();
    }

    function _harvest() internal override {
        address[] memory assets = new address[](1);
        assets[0] = AaveStrategyStorage.strategyStorage().aToken;

        IAaveV3Incentives(AAVE_INCENTIVES_CONTROLLER).claimRewards(
            assets,
            type(uint256).max,
            address(this),
            NATIVE_WRAPPED_TOKEN
        );

        uint256 nativeBal = IERC20(NATIVE_WRAPPED_TOKEN).balanceOf(
            address(this)
        );

        if (nativeBal > 0) {
            _swapRewards(nativeBal);
        }
    }

    // The sum of balanceOfPool
    function balanceOf() public view override returns (uint256) {
        return balanceOfPool();
    }

    // Calculates how much want the strategy has working in the farm
    function balanceOfPool() internal view returns (uint256 balance_) {
        balance_ = IERC20(AaveStrategyStorage.strategyStorage().aToken)
            .balanceOf(address(this));
    }

    function pendingRewards() public view override returns (uint256[] memory) {
        address[] memory assets = new address[](1);
        assets[0] = AaveStrategyStorage.strategyStorage().aToken;
        uint256[] memory bal = new uint256[](1);

        bal[0] = IAaveV3Incentives(AAVE_INCENTIVES_CONTROLLER).getUserRewards(
            assets,
            address(this),
            NATIVE_WRAPPED_TOKEN
        );

        return bal;
    }

    // swap rewards to {want}
    function _swapRewards(uint256 _nativeBalance) internal {
        uint256[] memory outAmount = IUniswapRouterETH(UNISWAP_V2_ROUTER)
            .getAmountsOut(
                _nativeBalance,
                AaveStrategyStorage.strategyStorage().nativeToWantRoute
            );

        uint256 wantOutAmount = outAmount[outAmount.length - 1];
        if (wantOutAmount > 0) {
            IUniswapRouterETH(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
                _nativeBalance,
                wantOutAmount,
                AaveStrategyStorage.strategyStorage().nativeToWantRoute,
                address(this),
                block.timestamp
            );
        }
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external override {
        AaveStrategyStorage
            .strategyStorage()
            .harvestOnDeposit = _harvestOnDeposit;
    }

    function getHarvestOnDeposit()
        external
        view
        override
        returns (bool harvestOnDeposit_)
    {
        harvestOnDeposit_ = AaveStrategyStorage
            .strategyStorage()
            .harvestOnDeposit;
    }

    function getStrategySource()
        external
        view
        override
        returns (address yieldSource_)
    {
        yieldSource_ = AaveStrategyStorage.strategyStorage().source;
    }
}
