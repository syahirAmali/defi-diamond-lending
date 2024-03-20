// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {InterestTokenBase} from "../tokenFacetBase/InterestTokenBase.sol";
import {PTokenStorage} from "./storage/PTokenStorage.sol";
import {ERC20MetadataStorage} from "../tokenFacetBase/metadata/ERC20MetadataStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokenManagerStorage} from "../TokenManagerFacet/storage/TokenManagerStorage.sol";
import {WadRayMath} from "../../libraries/math/WadRayMath.sol";
import {IOnwardIncentivesController} from "../../interfaces/IOnwardIncentivesController.sol";

contract PTokenFacet is InterestTokenBase {
    using WadRayMath for uint256;
    using ERC20MetadataStorage for ERC20MetadataStorage.Layout;
    using PTokenStorage for PTokenStorage.Layout;

    //***************************************************************//
    //  PToken Facet                                                 //
    //***************************************************************//

    //**Events*******************************************************//
    event Mint(address indexed _to, uint256 _amount, uint256 _index);
    event Burn(
        address indexed from,
        address indexed _receiverOfUnderlying,
        uint256 _amount,
        uint256 _index
    );

    //**Setters******************************************************//

    /// @notice mints pToken
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

    /// @notice mints pToken to treasury
    /// @notice can only be called by the core diamond contract
    /// @param _amount, amount to mint
    /// @param _index, value to scale the token amount by
    function mintToTreasury(uint256 _amount, uint256 _index) external {
        TokenManagerStorage.enforceIsCoreDiamondContract();
        address treasury = PTokenStorage.layout().treasury;

        // Compared to the normal mint, we don't check for rounding errors.
        // The amount to mint can easily be very small since it is a fraction of the interest accrued.
        // In that case, the treasury will experience a (very small) loss, but it
        // wont cause potentially valid transactions to fail.
        _mint(treasury, _amount.rayDiv(_index));

        emit Mint(treasury, _amount, _index);
    }

    function setTreasuryAddress(address _treasuryAddress) external {
        TokenManagerStorage.enforceIsCoreDiamondContract();
        PTokenStorage.layout().treasury = _treasuryAddress;
    }

    function getTreasuryAddress() external view returns (address) {
        return PTokenStorage.layout().treasury;
    }

    /// @notice burns pToken
    /// @notice can only be called by the core diamond contract
    /// @param _from, from whom to burn tokens from
    /// @param _amount, amount to burn
    /// @param _index, value to scale the token amount by
    function burn(
        address _from,
        address _receiverOfUnderlying,
        uint256 _amount,
        uint256 _index
    ) external {
        TokenManagerStorage.enforceIsCoreDiamondContract();

        super.burnScaled(_from, _amount, _index);
        if (_receiverOfUnderlying != address(this)) {
            IERC20(PTokenStorage.layout().underlyingAsset).transfer(
                _receiverOfUnderlying,
                _amount
            );
        }
        emit Burn(_from, _receiverOfUnderlying, _amount, _index);
    }

    /// @notice transfers the underlying asset to target
    /// @notice can only be called by the core diamond contract
    /// @param _target, target of the transfer of the underlying asset
    /// @param _amount, amount to be transffered
    function transferUnderlyingTo(address _target, uint256 _amount) external {
        TokenManagerStorage.enforceIsCoreDiamondContract();

        IERC20(PTokenStorage.layout().underlyingAsset).transfer(
            _target,
            _amount
        );
    }

    /// @notice Overrides the parent _transfer to force validated transfer() and transferFrom()
    /// @param holder The source address
    /// @param recipient The destination address
    /// @param amount The amount getting transferred
    function _transfer(
        address holder,
        address recipient,
        uint256 amount
    ) internal override {
        uint256 index = PTokenStorage.layout().pool.getNormalizedSupplyIndex(
            PTokenStorage.layout().underlyingAsset
        );

        uint256 fromBalanceBefore = super.balanceOf(holder).rayMul(index);
        uint256 toBalanceBefore = super.balanceOf(recipient).rayMul(index);

        super._transfer(holder, recipient, amount.rayDiv(index));

        PTokenStorage.layout().pool.finalizeTransfer(
            PTokenStorage.layout().underlyingAsset,
            holder,
            recipient,
            amount,
            fromBalanceBefore,
            toBalanceBefore
        );
    }

    /// @notice function to be executed after a token transfer
    function _afterTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal {}

    //**Getters******************************************************//

    /// @notice gets the balanceOf the pToken for a specific user
    /// @param _user, address to check the balance of pToken
    function balanceOf(address _user) public view override returns (uint256) {
        return
            super.balanceOf(_user).rayMul(
                PTokenStorage.layout().pool.getNormalizedSupplyIndex(
                    PTokenStorage.layout().underlyingAsset
                )
            );
    }

    /// @notice gets the total supply of the pToken
    function totalSupply() public view override returns (uint256) {
        return
            super.totalSupply().rayMul(
                PTokenStorage.layout().pool.getNormalizedSupplyIndex(
                    PTokenStorage.layout().underlyingAsset
                )
            );
    }
}
