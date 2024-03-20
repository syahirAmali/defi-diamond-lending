// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {ERC20MetadataStorage} from "../../tokenFacetBase/metadata/ERC20MetadataStorage.sol";

interface IPool {
    function finalizeTransfer(address _underlyingAsset, address _from) external;

    function getNormalizedBorrowIndex(
        address _underlyingAsset
    ) external view returns (uint256);
}

library DebtTokenStorage {

    using ERC20MetadataStorage for ERC20MetadataStorage.Layout;

    //**Storage******************************************************//
    
    struct Layout {
        address underlyingAsset;
        IPool pool;
        // Map of borrow allowances (delegator => delegatee => borrowAllowanceAmount)
        mapping(address => mapping(address => uint256)) borrowAllowance;
        bool init;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("solidstate.contracts.storage.debtToken");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    //**Setters******************************************************//

    function _init(
        address _underlyingAsset,
        address _pool,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) internal {
        ERC20MetadataStorage.Layout storage l = ERC20MetadataStorage.layout();

        require(!layout().init, "Init already executed!");

        l.setName(name);
        l.setSymbol(symbol);
        l.setDecimals(decimals);
        layout().underlyingAsset = _underlyingAsset;
        layout().pool = IPool(_pool);

        layout().init = true;
    }
}