// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {InterestTokenBase} from "../tokenFacetBase/InterestTokenBase.sol";
import {DebtTokenStorage} from "./storage/DebtTokenStorage.sol";
import {ERC20MetadataStorage} from "../tokenFacetBase/metadata/ERC20MetadataStorage.sol";
import {TokenManagerStorage} from "../TokenManagerFacet/storage/TokenManagerStorage.sol";
import {WadRayMath} from "../../libraries/math/WadRayMath.sol";

interface IPool {
    function finalizeTransfer(address _underlyingAsset, address _from) external;

    function getNormalizedBorrowIndex(
        address _underlyingAsset
    ) external view returns (uint256);
}

contract DebtTokenFacet is InterestTokenBase {
    //***************************************************************//
    //  Debt Token Facet                                             //
    //***************************************************************//

    using WadRayMath for uint256;
    using ERC20MetadataStorage for ERC20MetadataStorage.Layout;
    using DebtTokenStorage for DebtTokenStorage.Layout;

    //**Events*******************************************************//

    event Mint(
        address indexed _to,
        uint256 indexed _amount,
        uint256 indexed _index
    );
    event Burn(
        address indexed _from,
        uint256 indexed _amount,
        uint256 indexed _index
    );
    event BorrowAllowanceDelegatedIncreased(
        address indexed fromUser,
        address indexed toUser,
        address indexed asset,
        uint256 amount
    );
    event BorrowAllowanceDelegatedDecreased(
        address indexed fromUser,
        address indexed toUser,
        address indexed asset,
        uint256 amount
    );

    //**Setters******************************************************//

    /// @notice mints debt token
    /// @notice can only be called by the core diamond contract
    /// @param _to, receiver of the minted token
    /// @param _amount, amount to mint
    /// @param _index, value to scale the token amount by
    function mint(
        address _to,
        uint256 _amount,
        uint256 _index
    ) external returns (bool) {
        TokenManagerStorage.enforceIsCoreDiamondContract();
        uint256 previousBalance = super.balanceOf(_to);
        super.mintScaled(_to, _amount, _index);
        emit Mint(_to, _amount, _index);
        return previousBalance == 0;
    }

    /// @notice burns debt token
    /// @notice can only be called by the core diamond contract
    /// @param _from, from whom to burn tokens from
    /// @param _amount, amount to burn
    /// @param _index, value to scale the token amount by
    function burn(address _from, uint256 _amount, uint256 _index) external {
        TokenManagerStorage.enforceIsCoreDiamondContract();

        super.burnScaled(_from, _amount, _index);
        emit Burn(_from, _amount, _index);
    }

    /// @notice borrow delegation for borrow position
    /// @param _delegatee grant delegation power to this address
    /// @param _amount how much delegation power to grant
    function increaseBorrowDelegation(
        address _delegatee,
        uint256 _amount
    ) external {
        DebtTokenStorage.layout().borrowAllowance[msg.sender][
            _delegatee
        ] += _amount;
        emit BorrowAllowanceDelegatedIncreased(
            msg.sender,
            _delegatee,
            DebtTokenStorage.layout().underlyingAsset,
            _amount
        );
    }

    /// @notice decrease borrow delegation for borrow position
    /// @param _delegatee decrease delegation power to this address
    /// @param _amount how much delegation power to decrease
    function decreaseBorrowAllowance(
        address _delegatee,
        uint256 _amount
    ) external {
        uint256 currentAllowance = DebtTokenStorage.layout().borrowAllowance[
            msg.sender
        ][_delegatee];

        require(currentAllowance >= _amount, "!allowance");

        DebtTokenStorage.layout().borrowAllowance[msg.sender][
            _delegatee
        ] -= _amount;

        emit BorrowAllowanceDelegatedDecreased(
            msg.sender,
            _delegatee,
            DebtTokenStorage.layout().underlyingAsset,
            _amount
        );
    }

    /// @notice decrease borrow delegation for borrow position called by the core diamond
    /// @param _delegatee decrease delegation power to this address
    /// @param _amount how much delegation power to decrease
    function decreaseBorrowAllowanceDiamond(
        address _delegator,
        address _delegatee,
        uint256 _amount
    ) external {
        TokenManagerStorage.enforceIsCoreDiamondContract();

        uint256 currentAllowance = DebtTokenStorage.layout().borrowAllowance[
            _delegator
        ][_delegatee];

        require(currentAllowance >= _amount, "!allowance");

        DebtTokenStorage.layout().borrowAllowance[_delegator][
            _delegatee
        ] -= _amount;

        emit BorrowAllowanceDelegatedDecreased(
            _delegator,
            _delegatee,
            DebtTokenStorage.layout().underlyingAsset,
            _amount
        );
    }

    //**Getters******************************************************//

    /// @notice gets the balanceOf the debt token for a specific user
    /// @param _owner, address to check the balance of debt token
    function balanceOf(address _owner) public view override returns (uint256) {
        return
            super.balanceOf(_owner).rayMul(
                DebtTokenStorage.layout().pool.getNormalizedBorrowIndex(
                    DebtTokenStorage.layout().underlyingAsset
                )
            );
    }

    /// @notice gets the total supply of the debt token
    function totalSupply() public view override returns (uint256) {
        return
            super.totalSupply().rayMul(
                DebtTokenStorage.layout().pool.getNormalizedBorrowIndex(
                    DebtTokenStorage.layout().underlyingAsset
                )
            );
    }

    /// @notice gets the borrow allowance of a user to another
    function borrowAllowance(
        address _fromUser,
        address _toUser
    ) external view returns (uint256) {
        return DebtTokenStorage.layout().borrowAllowance[_fromUser][_toUser];
    }

    /**
     * @dev Being non transferrable, the debt token does not implement any of the
     * standard ERC20 functions for transfer and allowance.
     * debt tokens are transferred
     **/

    /// @notice Function is disabled due to being debt token
    function transfer(address, uint256) public virtual override returns (bool) {
        revert("Token: Operation not supported");
    }

    /// @notice Function is disabled due to being debt token
    function approve(address, uint256) public virtual override returns (bool) {
        revert("Token: Operation not supported");
    }

    /// @notice Function is disabled due to being debt token
    function allowance(
        address,
        address
    ) public view virtual override returns (uint256) {
        revert("Token: Operation not supported");
    }

    /// @notice Function is disabled due to being debt token
    function transferFrom(
        address,
        address,
        uint256
    ) public virtual override returns (bool) {
        revert("Token: Operation not supported");
    }

    /// @notice Function is disabled due to being debt token
    function increaseAllowance(
        address,
        uint256
    ) public virtual override returns (bool) {
        revert("Token: Operation not supported");
    }

    /// @notice Function is disabled due to being debt token
    function decreaseAllowance(
        address,
        uint256
    ) public virtual override returns (bool) {
        revert("Token: Operation not supported");
    }
}
