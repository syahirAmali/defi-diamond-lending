// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {ERC20Base} from "./base/ERC20Base.sol";
import {ERC20BaseStorage} from "./base/ERC20BaseStorage.sol";
import {ERC20Extended} from "./extended/ERC20Extended.sol";
import {ERC20Metadata} from "./metadata/ERC20Metadata.sol";
import {TokenManagerStorage} from "../TokenManagerFacet/storage/TokenManagerStorage.sol";

/**
 * @title SolidState ERC20 implementation, including recommended extensions
 */
abstract contract ERC20 is ERC20Base, ERC20Extended, ERC20Metadata {
    function setIncentivesController(address _incentivesController) external {
        TokenManagerStorage.enforceIsCoreDiamondContract();
        ERC20BaseStorage.layout().incentivesController = _incentivesController;
    }

    function getIncentivesController() external view returns (address) {
        return ERC20BaseStorage.layout().incentivesController;
    }
}
