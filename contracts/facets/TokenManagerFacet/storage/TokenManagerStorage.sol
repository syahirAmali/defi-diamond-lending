// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

library TokenManagerStorage {

    //**Storage******************************************************//

    bytes32 private constant TOKEN_STORAGE_POSITION =
        keccak256("diamond.standard.token.storage");

    struct TokenStorage {
        address vault;
        address coreDiamond;
    }

    function tokenManagerStorage()
        internal
        pure
        returns (TokenStorage storage ps)
    {
        bytes32 position = TOKEN_STORAGE_POSITION;
        assembly {
            ps.slot := position
        }
    }

    function enforceIsCoreDiamondContract() internal view {
        require(
            msg.sender == TokenManagerStorage.tokenManagerStorage().coreDiamond,
            "LibTokenManager: Must come from core diamond contract"
        );
    }
}
