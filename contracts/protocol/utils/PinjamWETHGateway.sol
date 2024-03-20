// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {IWETH} from "../../interfaces/IWETH.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPool {

    function deposit(
        address _underlyingAsset,
        uint256 _amount,
        address _to,
        bool _depositToVault
    ) external;

    function withdraw(
        address _underlyingAsset,
        uint256 _amount,
        address _to
    ) external;

    function repay(
        address _underlyingAsset,
        uint256 _amount,
        address _to
    ) external;

    function borrow(
        address _underlyingAsset,
        uint256 _amount,
        address _onBehalfOf
    ) external;

    function getPToken(
        address _underlyingAsset
    ) external view returns (address);

    function getDebtToken(
        address _underlyingAsset
    ) external view returns (address);
}

contract PinjamWETHGateway is Ownable {
    
    IWETH private immutable WETH;
    address private immutable coreDiamond;

    event Deposit(
        address indexed underlyingAsset,
        uint256 amount,
        address indexed from,
        address indexed to
    );
    event Withdraw(
        address indexed underlyingAsset,
        uint256 amount,
        address indexed from,
        address indexed to
    );
    event Borrow(
        address indexed underlyingAsset,
        uint256 amount,
        address indexed borrower
    );
    event Repay(
        address indexed underlyingAsset,
        uint256 amount,
        address indexed borrower
    );

    constructor(address weth, address diamond) {
        WETH = IWETH(weth);
        coreDiamond = address(diamond);
    }

    function depositEth(address _to, bool _depositToVault) external payable {
        WETH.approve(coreDiamond, msg.value);

        WETH.deposit{value: msg.value}();

        IPool(coreDiamond).deposit(
            address(WETH),
            msg.value,
            _to,
            _depositToVault
        );
        emit Deposit(address(WETH), msg.value, msg.sender, _to);
    }

    function withdrawEth(uint256 _amount, address _to) external {
        IERC20 pWETH = IERC20(IPool(coreDiamond).getPToken(address(WETH)));

        uint256 balance = pWETH.balanceOf(msg.sender);

        uint256 withdrawAmount = _amount;

        // if amount is equal to uint(-1), the user wants to redeem everything
        if (_amount == type(uint256).max) {
            withdrawAmount = balance;
        }

        pWETH.transferFrom(msg.sender, address(this), withdrawAmount);

        IPool(coreDiamond).withdraw(
            address(WETH),
            withdrawAmount,
            address(this)
        );

        WETH.withdraw(withdrawAmount);

        _safeTransferETH(_to, withdrawAmount);
        emit Withdraw(address(WETH), _amount, msg.sender, _to);
    }

    function repayEth(address _to, uint256 _amount) external payable {
        IERC20 debtWETH = IERC20(
            IPool(coreDiamond).getDebtToken(address(WETH))
        );

        uint256 maxDebt = debtWETH.balanceOf(_to);

        if (_amount < maxDebt) {
            maxDebt = _amount;
        }

        require(msg.value >= maxDebt, "!msg.value");

        WETH.deposit{value: maxDebt}();

        WETH.approve(address(coreDiamond), msg.value);

        IPool(coreDiamond).repay(address(WETH), msg.value, _to);

        // refunds extra eth if any
        if (msg.value > maxDebt) {
            _safeTransferETH(msg.sender, msg.value - maxDebt);
        }

        emit Repay(address(WETH), msg.value, _to);
    }

    function borrowEth(uint256 _amount) external {
        IPool(coreDiamond).borrow(address(WETH), _amount, msg.sender);
        WETH.withdraw(_amount);
        _safeTransferETH(msg.sender, _amount);
        emit Borrow(address(WETH), _amount, msg.sender);
    }

    /**
     * @dev transfer ETH to an address, revert if it fails.
     * @param to recipient of the transfer
     * @param value the amount to send
     */
    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED");
    }

    function emergencyTokenTransfer(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }

    function emergencyEthTransfer(
        address _to,
        uint256 _amount
    ) external onlyOwner {
        _safeTransferETH(_to, _amount);
    }

    /**
     * @dev Only WETH contract is allowed to transfer ETH here. Prevent other addresses to send Ether to this contract.
     */
    receive() external payable {
        require(msg.sender == address(WETH), "Receive not allowed");
    }

    /**
     * @dev Revert fallback calls
     */
    fallback() external payable {
        revert("Fallback not allowed");
    }
}
