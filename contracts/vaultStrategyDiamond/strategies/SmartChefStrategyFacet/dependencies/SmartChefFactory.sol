// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./SmartChefInitializable.sol";

contract SmartChefFactory is Ownable {
    event NewSmartChefContract(address indexed smartChef);

    address pool;

    constructor() {
    }

    /*
     * @notice Deploy the pool
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerBlock: reward per block (in rewardToken)
     * @param _startBlock: start block
     * @param _endBlock: end block
     * @param _poolLimitPerUser: pool limit per user in stakedToken (if any, else 0)
     * @param _numberBlocksForUserLimit: block numbers available for user limit (after start block)
     * @param _pancakeProfile: Pancake Profile address
     * @param _pancakeProfileIsRequested: Pancake Profile is requested
     * @param _pancakeProfileThresholdPoints: Pancake Profile need threshold points
     * @param _admin: admin address with ownership
     * @return address of new smart chef contract
     */
    function deployPool(
        IERC20Metadata _stakedToken,
        IERC20Metadata _rewardToken,
        uint256 _rewardPerBlock,
        address _admin
    ) external onlyOwner{
        require(_stakedToken.totalSupply() >= 0);
        require(_rewardToken.totalSupply() >= 0);
        // require(_stakedToken != _rewardToken, "Tokens must be be different");

        bytes memory bytecode = type(SmartChefInitializable).creationCode;
        // pass constructor argument
        bytecode = abi.encodePacked(
            bytecode,
            abi.encode()
        );
        bytes32 salt = keccak256(abi.encodePacked(_stakedToken, _rewardToken));
        address smartChefAddress;

        assembly {
            smartChefAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        SmartChefInitializable(smartChefAddress).initialize(
            _stakedToken,
            _rewardToken,
            _rewardPerBlock,
            block.timestamp,
            block.timestamp + 1000000,
            _admin
        );

        pool = smartChefAddress;

        emit NewSmartChefContract(smartChefAddress);
    }

    function getPool() external view returns (address pool_) {
        pool_ = pool;
    }
}