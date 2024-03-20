pragma solidity ^0.8.0;
interface IEquilibreRouter {
    struct route {
        address from;
        address to;
        bool stable;
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] memory routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(
        uint256 amountIn,
        route[] memory routes
    ) external returns (uint256[] calldata);

    function pairFor(
        address tokenA, 
        address tokenB, 
        bool stable
    ) external returns (address pair);
    
    function swapAVAXForExactTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}
