// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultStorage} from "../../storage/VaultStorage.sol";
import {SimpleRewards} from "../../../mock/SimpleRewards.sol";
import {IPinjamStrategy} from "../../interfaces/IPinjamStrategy.sol";
import {LibSimpleRewardsStrategyStorage} from "./storage/SimpleRewardsStrategyStorage.sol";

contract SimpleRewardsStrategyFacet is IPinjamStrategy {
    using SafeERC20 for IERC20;

    function init(
        LibSimpleRewardsStrategyStorage.StrategyStorageLayout memory _stratInit
    ) external {
        LibSimpleRewardsStrategyStorage.init(_stratInit);
    }

    function deposit(uint256 _amount) public override {
        IERC20(VaultStorage.vaultStorage().want).safeApprove(
            LibSimpleRewardsStrategyStorage.strategyStorage().source,
            _amount
        );

        SimpleRewards(LibSimpleRewardsStrategyStorage.strategyStorage().source)
            .deposit(_amount);

        emit Deposit(_amount);
    }

    function withdraw(
        address _to,
        uint256 _amount
    ) public override returns (uint256) {
        if (_amount > balanceOfPool()) {
            _amount = balanceOfPool();
        }

        SimpleRewards(LibSimpleRewardsStrategyStorage.strategyStorage().source)
            .withdraw(_amount);

        IERC20(VaultStorage.vaultStorage().want).safeTransfer(_to, _amount);
        emit Withdraw(_to, _amount);

        return _amount;
    }

    function _beforeDeposit() internal override {}

    function _harvest() internal override {}

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

    // Calculates how much 'want; the strategy has working in the farm
    function balanceOfPool() internal view returns (uint256 balance_) {
        balance_ = SimpleRewards(
            LibSimpleRewardsStrategyStorage.strategyStorage().source
        ).userDeposit(address(this));
    }

    function pendingRewards()
        public
        view
        override
        returns (uint256[] memory balance_)
    {
        uint256[] memory bal = new uint256[](1);

        bal[0] = SimpleRewards(
            LibSimpleRewardsStrategyStorage.strategyStorage().source
        ).pendingReward();
        balance_ = bal;
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external override {
        LibSimpleRewardsStrategyStorage
            .strategyStorage()
            .harvestOnDeposit = _harvestOnDeposit;
    }

    function getHarvestOnDeposit()
        external
        view
        override
        returns (bool _harvestOnDeposit)
    {
        _harvestOnDeposit = LibSimpleRewardsStrategyStorage
            .strategyStorage()
            .harvestOnDeposit;
    }

    function getStrategySource()
        external
        view
        override
        returns (address yieldSource_)
    {
        yieldSource_ = LibSimpleRewardsStrategyStorage.strategyStorage().source;
    }
}
