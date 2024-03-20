pragma solidity ^0.8.0;
interface IEquilibrePair {
    function current(
        address tokenIn,
        uint amountIn
    ) external view returns (uint amountOut);

    function swap(
        uint amount0Out, 
        uint amount1Out, 
        address to, 
        bytes calldata data
    ) external;
}
