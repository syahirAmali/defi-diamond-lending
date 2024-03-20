// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

abstract contract IPinjamStrategy {
    event Deposit(uint256 tvl);
    event Withdraw(address indexed _to, uint256 amount);

    function _beforeDeposit() internal virtual;

    function _harvest() internal virtual;

    function deposit(uint256 _amount) external virtual;

    // returns actual withdrawed amount
    function withdraw(
        address _to,
        uint256 _amount
    ) external virtual returns (uint256);

    function harvest() external virtual {}

    // The sum of balanceOfWant + balanceOfPool + pendingRewards
    function balanceOf() external view virtual returns (uint256);

    // Pending rewards earned
    function pendingRewards()
        external
        view
        virtual
        returns (uint256[] memory balance_);

    function setHarvestOnDeposit(bool _harvestOnDeposit) external virtual;

    function getHarvestOnDeposit()
        external
        view
        virtual
        returns (bool harvestOnDeposit_);

    function getStrategySource()
        external
        view
        virtual
        returns (address yieldSource_);
}
