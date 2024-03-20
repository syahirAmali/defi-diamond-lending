// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultStorage} from "../../storage/VaultStorage.sol";
import {SimpleRewards} from "../../../mock/SimpleRewards.sol";
import {IPinjamStrategy} from "../../interfaces/IPinjamStrategy.sol";
import {ISmartChefInitializable} from "./interfaces/ISmartChefInitializable.sol";
import {LibSmartChefStrategyStorage} from "./storage/SmartChefStrategyStorage.sol";

contract SmartChefStrategyFacet is IPinjamStrategy {
    using SafeERC20 for IERC20;

    function init(
        LibSmartChefStrategyStorage.StrategyStorageLayout memory _stratInit
    ) external {
        LibSmartChefStrategyStorage.init(_stratInit);
    }

    function _beforeDeposit() internal override {
        if (LibSmartChefStrategyStorage.strategyStorage().harvestOnDeposit) {
            _harvest();
        }
    }

    function deposit(uint256 _amount) public override {
        _beforeDeposit();
        IERC20(VaultStorage.vaultStorage().want).safeApprove(
            LibSmartChefStrategyStorage.strategyStorage().source,
            _amount
        );
        ISmartChefInitializable(
            LibSmartChefStrategyStorage.strategyStorage().source
        ).deposit(_amount);
        emit Deposit(_amount);
    }

    function withdraw(
        address _to,
        uint256 _amount
    ) public override returns (uint256) {
        if (_amount > balanceOfPool()) {
            _amount = balanceOfPool();
        }

        ISmartChefInitializable(
            LibSmartChefStrategyStorage.strategyStorage().source
        ).withdraw(_amount);

        IERC20(VaultStorage.vaultStorage().want).safeTransfer(_to, _amount);

        emit Withdraw(_to, balanceOf());

        // if (!VaultStorage.vaultStorage().strategies[0].paused) {
        //     sm_deposit(balanceOfWant());
        // }

        return _amount;
    }

    function _harvest() internal override {
        ISmartChefInitializable(
            LibSmartChefStrategyStorage.strategyStorage().source
        ).deposit(0);

        uint256 wantTokenHarvested = balanceOfWant();

        if (wantTokenHarvested > 0) {
            deposit(wantTokenHarvested);
        }
    }

    // The sum of balanceOfPool + pendingRewards
    function balanceOf() public view override returns (uint256) {
        uint256 pendingRewardSum;

        uint256[] memory pendingRewardsArray = pendingRewards();

        // This implementation only works for this strategy because it returns 1 type of rewards
        for (uint8 i = 0; i < pendingRewardsArray.length; ++i) {
            pendingRewardSum += pendingRewardsArray[i];
        }

        return balanceOfPool() + pendingRewardSum;
    }

    function balanceOfWant() internal view returns (uint256 balance_) {
        balance_ = IERC20(VaultStorage.vaultStorage().want).balanceOf(
            address(this)
        );
    }

    // Calculates how much 'want; the strategy has working in the farm
    function balanceOfPool() internal view returns (uint256 balance_) {
        ISmartChefInitializable.UserInfo memory info = ISmartChefInitializable(
            LibSmartChefStrategyStorage.strategyStorage().source
        ).userInfo(address(this));
        balance_ = info.amount;
    }

    function pendingRewards()
        public
        view
        override
        returns (uint256[] memory balance_)
    {
        uint256[] memory bal = new uint256[](1);

        bal[0] = ISmartChefInitializable(
            LibSmartChefStrategyStorage.strategyStorage().source
        ).pendingReward(address(this));

        balance_ = bal;
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external override {
        LibSmartChefStrategyStorage
            .strategyStorage()
            .harvestOnDeposit = _harvestOnDeposit;
    }

    function getHarvestOnDeposit()
        external
        view
        override
        returns (bool _harvestOnDeposit)
    {
        _harvestOnDeposit = LibSmartChefStrategyStorage
            .strategyStorage()
            .harvestOnDeposit;
    }

    function getStrategySource()
        external
        view
        override
        returns (address yieldSource_)
    {
        yieldSource_ = LibSmartChefStrategyStorage.strategyStorage().source;
    }
}
