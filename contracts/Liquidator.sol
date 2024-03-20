// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {IEquilibreRouter} from "./vaultStrategyDiamond/strategies/MareStrategyFacet/interfaces/IEquilibreRouter.sol";

interface IPinjamPool {
    function liquidate(
        address _user,
        address _underlyingCollateralAsset,
        address _underlyingDebtAsset,
        uint256 _debtToCover,
        bool _allowSwaps,
        bytes calldata params
    ) external;

    function withdraw(
        address underlyingAsset,
        uint256 amount,
        address to
    ) external;
}

interface ICurveFinance {
    struct CurveSwap {
        address pool;
        address fromToken;
        int128 i;
        int128 j;
        uint256 dx;
        uint256 min_dy;
        bool enabled;
    }

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);
}

interface IERC20 {
    function transfer(address to, uint256 amount) external;

    function approve(address spender, uint256 amount) external;

    function balanceOf(address user) external returns (uint256);
}

contract Liquidator {
    address public owner;
    mapping(address => bool) public liquidators;
    address public pinjamPool;
    address public payee;

    address public constant EQUILIBRE_ROUTER =
        0xA7544C409d772944017BB95B99484B6E0d7B6388;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only Owner");
        _;
    }

    modifier onlyLiquidator() {
        require(liquidators[msg.sender] == true, "Only Liquidator");
        _;
    }

    constructor(address _poolFacet) {
        pinjamPool = _poolFacet;

        owner = msg.sender;
    }

    function addLiquidator(address _liquidator) external onlyOwner {
        liquidators[_liquidator] = true;
    }

    function removeLiquidator(address _liquidator) external onlyOwner {
        liquidators[_liquidator] = false;
    }

    function transferOwner(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }

    function liquidate(
        address _user,
        address _underlyingCollateralAsset,
        address _underlyingDebtAsset,
        uint256 _debtToCover,
        bool _allowSwaps,
        IEquilibreRouter.route[] calldata _equilibreBeforeRoutes,
        ICurveFinance.CurveSwap calldata _curveSwap,
        IEquilibreRouter.route[] calldata _equilibreAfterRoutes
    ) external onlyLiquidator {
        IERC20(_underlyingDebtAsset).approve(pinjamPool, type(uint256).max);

        IPinjamPool(pinjamPool).liquidate(
            _user,
            _underlyingCollateralAsset,
            _underlyingDebtAsset,
            _debtToCover,
            _allowSwaps,
            abi.encode(
                _equilibreBeforeRoutes,
                _curveSwap,
                _equilibreAfterRoutes
            )
        );
    }

    function handleSwap(
        uint256 _actualCollateralAmount,
        uint256 _actualDebtAmount,
        bytes calldata params
    ) external {
        require(msg.sender == pinjamPool, "!pinjamPool");
        (
            IEquilibreRouter.route[] memory _equilibreBeforeRoutes,
            ICurveFinance.CurveSwap memory _curveSwap,
            IEquilibreRouter.route[] memory _equilibreAfterRoutes
        ) = abi.decode(
                params,
                (
                    IEquilibreRouter.route[],
                    ICurveFinance.CurveSwap,
                    IEquilibreRouter.route[]
                )
            );

        uint256 lastAmountOut = _actualCollateralAmount;

        if (_equilibreBeforeRoutes.length > 0) {
            lastAmountOut = _swapEquilibreAssets(
                _equilibreBeforeRoutes,
                lastAmountOut
            );
        }

        if (_curveSwap.enabled) {
            lastAmountOut = _swapCurveAssets(_curveSwap, lastAmountOut);
        }

        if (_equilibreAfterRoutes.length > 0) {
            lastAmountOut = _swapEquilibreAssets(
                _equilibreAfterRoutes,
                lastAmountOut
            );
        }
    }

    function withdrawFromPool(
        address _underlyingAsset,
        uint256 _amount,
        address _to
    ) external onlyOwner {
        IPinjamPool(pinjamPool).withdraw(_underlyingAsset, _amount, _to);
    }

    function withdrawTokens(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }

    // swap rewards to {want}
    function _swapEquilibreAssets(
        IEquilibreRouter.route[] memory _routes,
        uint256 amountIn
    ) internal returns (uint256) {
        for (uint256 i; i < _routes.length; i++) {
            _approveToken(_routes[i].from, EQUILIBRE_ROUTER, type(uint256).max);
        }

        uint[] memory amounts = IEquilibreRouter(EQUILIBRE_ROUTER)
            .swapExactTokensForTokens(
                amountIn,
                0,
                _routes,
                address(this),
                block.timestamp
            );

        return amounts[amounts.length - 1];
    }

    function _swapCurveAssets(
        ICurveFinance.CurveSwap memory _curveSwap,
        uint256 amountIn
    ) internal returns (uint256) {
        _approveToken(_curveSwap.fromToken, _curveSwap.pool, type(uint256).max);

        return
            ICurveFinance(_curveSwap.pool).exchange(
                _curveSwap.i,
                _curveSwap.j,
                amountIn,
                0
            );
    }

    function _approveToken(
        address _token,
        address _spender,
        uint256 _amount
    ) internal {
        IERC20(_token).approve(_spender, _amount);
    }
}
