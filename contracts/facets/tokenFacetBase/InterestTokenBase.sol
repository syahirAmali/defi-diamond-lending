// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {ERC20} from "./ERC20.sol";
import {WadRayMath} from "../../libraries/math/WadRayMath.sol";

abstract contract InterestTokenBase is ERC20 {
    using WadRayMath for uint256;
    // access control for this
    function mintScaled(
        address _user,
        uint256 _amount,
        uint256 _index
    ) internal {
        uint256 _amountScaled =  _amount.rayDiv(_index);
        require(_amountScaled != 0, "InterestTokenBase: Incorrect Amount");
        _mint(_user, _amountScaled);
    }

    // access control for this
    function burnScaled(
        address _user,
        uint256 _amount,
        uint256 _index
    ) internal {
        uint256 _amountScaled = _amount.rayDiv(_index);
        require(_amountScaled != 0, "InterestTokenBase: Incorrect Amount");

        _burn(_user, _amountScaled);
    }
}
