// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

library AddressRegistryStorage {

    //**Storage******************************************************//

    bytes32 private constant ADDRESS_REGISTRY_STORAGE_POSITION =
        keccak256("diamond.standard.addressRegistry.storage");

    struct RegistryStorage {
        address addressRegistry;
        address accessControl;
        address diamondCut;
        address diamondLoupe;
        address oracle;
        address poolManager;
        address pToken;
        address debtToken;
        address pool;
        address tokenManager;
        address poolFactory;
        address poolData;
        address wethGateway;
    }

    function registryStorage() internal pure returns (RegistryStorage storage rs) {
        bytes32 position = ADDRESS_REGISTRY_STORAGE_POSITION;
        assembly {
            rs.slot := position
        }
    }
}
