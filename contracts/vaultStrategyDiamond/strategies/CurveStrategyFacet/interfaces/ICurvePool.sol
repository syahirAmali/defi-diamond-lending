// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;
interface ICurvePool {
    function add_liquidity(uint256[] calldata uamounts, uint256 min_mint_amount) external;
    function remove_liquidity(uint256 _amount, uint256[] calldata min_uamounts) external;
    function remove_liquidity_one_coin(uint256 _tokenAmoun, uint128 _i, uint256 _minAmount) external;

    function calc_withdraw_one_coin(uint256 _tokenAmount, uint128 _i) external returns (uint256);
    function get_virtual_price() external view returns (uint256);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);

    function get_dy(int128 i, int128 j, uint256 dx) external returns (uint256);
}
