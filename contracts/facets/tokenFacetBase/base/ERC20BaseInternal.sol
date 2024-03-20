// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {IERC20Internal} from "../IERC20Internal.sol";
import {ERC20BaseStorage} from "./ERC20BaseStorage.sol";
import {IOnwardIncentivesController} from "../../../interfaces/IOnwardIncentivesController.sol";

/**
 * @title Base ERC20 implementation, excluding optional extensions
 */
abstract contract ERC20BaseInternal is IERC20Internal {
    /**
     * @notice query the total minted token supply
     * @return token supply
     */
    function _totalSupply() internal view virtual returns (uint256) {
        return ERC20BaseStorage.layout().totalSupply;
    }

    /**
     * @notice query the token balance of given account
     * @param account address to query
     * @return token balance
     */
    function _balanceOf(
        address account
    ) internal view virtual returns (uint256) {
        return ERC20BaseStorage.layout().balances[account];
    }

    /**
     * @notice enable spender to spend tokens on behalf of holder
     * @param holder address on whose behalf tokens may be spent
     * @param spender recipient of allowance
     * @param amount quantity of tokens approved for spending
     */
    function _approve(
        address holder,
        address spender,
        uint256 amount
    ) internal virtual {
        require(holder != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        ERC20BaseStorage.layout().allowances[holder][spender] = amount;

        emit Approval(holder, spender, amount);
    }

    /**
     * @notice mint tokens for given account
     * @param account recipient of minted tokens
     * @param amount quantity of tokens minted
     */
    function _mint(address account, uint256 amount) internal virtual {
        ERC20BaseStorage.Layout storage l = ERC20BaseStorage.layout();
        l.totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            l.balances[account] += amount;
        }

        if (l.incentivesController != address(0)) {
            IOnwardIncentivesController(l.incentivesController).handleAction(
                account,
                l.balances[account],
                l.totalSupply
            );
        }

        emit Transfer(address(0), account, amount);
    }

    /**
     * @notice burn tokens held by given account
     * @param account holder of burned tokens
     * @param amount quantity of tokens burned
     */
    function _burn(address account, uint256 amount) internal virtual {
        ERC20BaseStorage.Layout storage l = ERC20BaseStorage.layout();
        l.balances[account] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            l.totalSupply -= amount;
        }

        if (l.incentivesController != address(0)) {
            IOnwardIncentivesController(l.incentivesController).handleAction(
                account,
                l.balances[account],
                l.totalSupply
            );
        }

        emit Transfer(account, address(0), amount);
    }

    /**
     * @notice transfer tokens from holder to recipient
     * @param holder owner of tokens to be transferred
     * @param recipient beneficiary of transfer
     * @param amount quantity of tokens transferred
     */
    function _transfer(
        address holder,
        address recipient,
        uint256 amount
    ) internal virtual {
        ERC20BaseStorage.Layout storage l = ERC20BaseStorage.layout();
        l.balances[holder] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            l.balances[recipient] += amount;
        }

        if (l.incentivesController != address(0)) {
            uint256 currentTotalSupply = l.totalSupply;

            IOnwardIncentivesController(l.incentivesController).handleAction(
                holder,
                l.balances[holder],
                currentTotalSupply
            );
            if (holder != recipient) {
                IOnwardIncentivesController(l.incentivesController)
                    .handleAction(
                        recipient,
                        l.balances[recipient],
                        currentTotalSupply
                    );
            }
        }

        emit Transfer(holder, recipient, amount);
    }
}
