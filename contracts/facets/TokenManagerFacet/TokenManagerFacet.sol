// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;
import {TokenManagerStorage} from "./storage/TokenManagerStorage.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {PTokenStorage} from "../PTokenFacet/storage/PTokenStorage.sol";

interface Vault {
    function deposit() external;

    function balance() external view returns (uint256);

    function withdraw(address _to, uint256 _amount) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external;
}

contract TokenManagerFacet {

    //***************************************************************//
    //  Token Manager Facet                                          //
    //***************************************************************//

    //**Events*******************************************************//
    event SetVault(address _vault);
    event WorkFunds(uint256 _amount);
    event WithdrawFunds(uint256 _amount);

    //**Setters******************************************************//

    function setVault(address _vault) external {
        TokenManagerStorage.enforceIsCoreDiamondContract();
        TokenManagerStorage.tokenManagerStorage().vault = _vault;
        emit SetVault(_vault);
    }

    function workFunds(uint256 _amount) external {
        TokenManagerStorage.enforceIsCoreDiamondContract();

        require(_amount != 0, "!amount");

        address vault = TokenManagerStorage.tokenManagerStorage().vault;
        require(vault != address(0), "!vault");

        IERC20(PTokenStorage.layout().underlyingAsset).transfer(vault, _amount);
        Vault(vault).deposit();

        emit WorkFunds(_amount);
    }

    function withdrawFunds(uint256 _amount) external {
        TokenManagerStorage.enforceIsCoreDiamondContract();

        address vault = TokenManagerStorage.tokenManagerStorage().vault;

        if (vault == address(0)) {
            return;
        }

        Vault(vault).withdraw(address(this), _amount);        
        
        emit WithdrawFunds(_amount);
    }

    //**Getters******************************************************//
    
    function getBalance() external view returns (uint256 balance_) {
        address vault = TokenManagerStorage.tokenManagerStorage().vault;
        if (vault == address(0)) {
            return balance_ = 0;
        }

        balance_ = Vault(vault).balance();
    }

    function getVault() external view returns (address vault_) {
        vault_ = TokenManagerStorage.tokenManagerStorage().vault;
    }
}
