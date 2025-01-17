// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

interface IWETH {

  function deposit() external payable;
  function withdraw(uint256) external;
  function approve(address guy, uint256 wad) external returns (bool);
  function transferFrom(address src, address dst, uint256 wad) external returns (bool);

}
