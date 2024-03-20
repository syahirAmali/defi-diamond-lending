// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

abstract contract IPinjamStrategy {
    address public constant MULTI_USDC_ADDRESS =
        0xfA9343C3897324496A05fC75abeD6bAC29f8A40f;
    address public constant NATIVE_WRAPPED_TOKEN =
        0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b;
    address public constant UNISWAP_V2_ROUTER =
        0xA7544C409d772944017BB95B99484B6E0d7B6388;
    uint256 public constant MAX_BP = 10000;
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
