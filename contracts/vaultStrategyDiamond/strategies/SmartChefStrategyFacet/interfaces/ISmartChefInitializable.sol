// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

/**
 * @title ISmartChefInitializable
 */
interface ISmartChefInitializable {

    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 rewardDebt; // Reward debt
    }

    function deposit(uint256 _amount) external;
 
    function withdraw(uint256 _amount) external;

    function pendingReward(address _user) external view returns (uint256);

    function userInfo(address _user) external view returns (UserInfo memory);
    
    function rewardPerBlock() external view returns (uint256);
}