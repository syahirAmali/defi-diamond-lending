// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

interface ICurveGauge {
    function deposit(uint256 _value) external;
    function withdraw(uint256 _value) external;
    function claimable_reward(address _userAddress, address _rewardToken) external view returns (uint256);
    function claim_rewards() external;
}
