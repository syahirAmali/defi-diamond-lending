// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {AddressRegistryStorage} from "../../facets/AddressRegistryFacet/storage/AddressRegistryStorage.sol";
import {AccessControlStorage} from "../../facets/AccessControlFacet/storage/AccessControlStorage.sol";
import {IDiamondLoupe} from "../../facets/diamondLoupe/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "../../facets/diamondCut/interfaces/IDiamondCut.sol";
import {IERC173} from "../../interfaces/IERC173.sol";
import {IERC165} from "../../interfaces/IERC165.sol";

contract DiamondInitMain {
    function init(address[] memory facetAddresses) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        require(!ds.init, "Init already execute!");

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        LibDiamond.enforceIsContractOwner();
        AccessControlStorage.accessControlStorage().adminAccount[msg.sender].status = true;        
        AddressRegistryStorage.registryStorage().addressRegistry = facetAddresses[0];
        AddressRegistryStorage.registryStorage().debtToken = facetAddresses[1];
        AddressRegistryStorage.registryStorage().pToken = facetAddresses[2];
        AddressRegistryStorage.registryStorage().accessControl = facetAddresses[3];
        AddressRegistryStorage.registryStorage().diamondCut = facetAddresses[4];
        AddressRegistryStorage.registryStorage().diamondLoupe = facetAddresses[5];
        AddressRegistryStorage.registryStorage().oracle = facetAddresses[6];
        AddressRegistryStorage.registryStorage().poolManager = facetAddresses[7];
        AddressRegistryStorage.registryStorage().pool = facetAddresses[8];
        AddressRegistryStorage.registryStorage().tokenManager = facetAddresses[9];
        AddressRegistryStorage.registryStorage().poolFactory = facetAddresses[10];
        AddressRegistryStorage.registryStorage().poolData = facetAddresses[11];

        ds.init = true;
    }
}
