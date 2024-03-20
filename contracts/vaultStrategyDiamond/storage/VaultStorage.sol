// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.0;

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {Errors} from "../../libraries/helpers/Errors.sol";

library VaultStorage {
    bytes32 private constant VAULT_STORAGE_POSITION =
        keccak256("diamond.standard.vault.storage");

    struct StrategyInfo {
        address strategy;
        bool paused;
    }

    struct VaultStorageLayout {
        address pToken;
        address diamond;
        address want;
        uint256 strategyCount;
        StrategyInfo[] strategies;
        bool init;
        uint256 defaultStrategyIndex; // Determines which default strategy index to deposit into
        bool strategiesFrozen; // Set to true if strategies are frozen so that it wont deposit dust values
    }

    function vaultStorage()
        internal
        pure
        returns (VaultStorageLayout storage vs)
    {
        bytes32 position = VAULT_STORAGE_POSITION;
        assembly {
            vs.slot := position
        }
    }

    function _onlyPToken() internal view {
        require(
            msg.sender == vaultStorage().pToken,
            Errors.CALLER_MUST_BE_PTOKEN
        );
    }

    function init(VaultStorageLayout memory _initParams) internal {
        require(msg.sender == LibDiamond.contractOwner(), "!owner");
        require(!vaultStorage().init, "Init already executed!");

        vaultStorage().pToken = _initParams.pToken;
        vaultStorage().diamond = _initParams.diamond;
        vaultStorage().want = _initParams.want;

        vaultStorage().init = true;
    }
}
