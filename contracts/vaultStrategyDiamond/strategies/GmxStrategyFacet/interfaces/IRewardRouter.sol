// SPDX-License-Identifier: BUSL 1.1

pragma solidity >=0.6.0 <0.9.0;

interface IRewardRouter {
    function stakeGmx(
        uint256 _amount
    ) external;

    function unstakeGmx(
        uint256 _amount
    ) external;

    function handleRewards(
        bool _shouldClaimGmx,
        bool _shouldStakeGmx,
        bool _shouldClaimEsGmx,
        bool _shouldStakeEsGmx,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth
    ) external;

    function compound() external;
}

interface IRewardReader {
    function getDepositBalances(
        address _account,
        address[] memory _depositTokens,
        address[] memory _rewardTrackers
    ) external view returns(uint256[] memory);

    function getStakingInfo(
        address _account,
        address[] memory _rewardTrackers
    ) external view returns(uint256[] memory);

    function getVestingInfoV2(
        address _account,
        address[] memory _vesters
    ) external view returns(uint256[] memory);

    function claimable(
        address _account
    ) external view returns(uint256);

    function claim(
        address receiver
    ) external;
}