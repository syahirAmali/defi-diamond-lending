// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;
pragma abicoder v2;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SimpleRewards is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    uint256 public depositBal;

    // The reward token
    IERC20Metadata public rewardToken;

    // The staked token
    IERC20Metadata public stakedToken;

    uint256 public totalRewards;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => uint256) public userDeposit;

    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event RewardsStop(uint256 blockNumber);
    event TokenRecovery(address indexed token, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event UpdateProfileAndThresholdPointsRequirement(
        bool isProfileRequested,
        uint256 thresholdPoints
    );

    /**
     * @notice Constructor
     */
    constructor(IERC20Metadata _stakedToken, IERC20Metadata _rewardToken) {
        stakedToken = _stakedToken;
        rewardToken = _rewardToken;
    }

    /*
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function deposit(uint256 _amount) external nonReentrant {
        if (userDeposit[msg.sender] > 0) {
            uint256 pending = pendingReward();
            if (pending > 0) {
                rewardToken.safeTransfer(address(msg.sender), pending);
                totalRewards -= pending;
            }
        }

        if (_amount > 0) {
            userDeposit[msg.sender] = userDeposit[msg.sender] + _amount;
            stakedToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
        }

        depositBal += _amount;

        emit Deposit(msg.sender, _amount);
    }

    function depositRewards(uint256 _amount) external {
        totalRewards += _amount;
        rewardToken.transferFrom(msg.sender, address(this), _amount);
    }

    /*
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(
            userDeposit[msg.sender] >= _amount,
            "Amount to withdraw too high"
        );

        uint256 pending = pendingReward();
        if (_amount > 0) {
            userDeposit[msg.sender] = userDeposit[msg.sender] - _amount;
            stakedToken.safeTransfer(address(msg.sender), _amount);
        }

        if (pending > 0) {
            rewardToken.safeTransfer(address(msg.sender), pending);
            totalRewards -= pending;
        }

        emit Withdraw(msg.sender, _amount);
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward() public view returns (uint256) {
        return totalRewards;
    }
}
