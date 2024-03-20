// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {IERC173} from "../../interfaces/IERC173.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {AccessControlStorage} from "./storage/AccessControlStorage.sol";

contract AccessControlFacet is IERC173 {

    //***************************************************************//
    //  Access Control Facet                                         //
    //***************************************************************//

    //**Events*******************************************************//
    event TransferOwnership(address indexed newOwner);
    event AddAdmin(address indexed _newAdmin);
    event RemoveAdmin(address indexed _admin);

    //**Setters******************************************************//
    
    /// @notice transfers ownership to a new address
    /// @param _newOwner, new address for the owner of the diamond
    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);

        emit TransferOwnership(_newOwner);
    }

    /// @notice adds an address as an admin for the diamond
    /// @notice can only be added by the owner
    /// @param _admin, adress to be added as admin
    function addAdmin(address _admin) external {
        LibDiamond.enforceIsContractOwner();
        AccessControlStorage.accessControlStorage().adminAccount[_admin].status = true;

        emit AddAdmin(_admin);
    }

    /// @notice removes an address as an admin for the diamond
    /// @notice can only be removed by the owner
    /// @param _admin, adress to be removed as admin
    function removeAdmin(address _admin) external {
        LibDiamond.enforceIsContractOwner();
        AccessControlStorage.accessControlStorage().adminAccount[_admin].status = false;

        emit RemoveAdmin(_admin);
    }

    /// @notice Checks if the caller is owner
    function isOwner() public view returns (address){
        return LibDiamond.contractOwner();
    }

    //**Getters******************************************************//

    /// @notice gets the current owner of the diamond
    function owner() external view returns (address _owner) {
        _owner = LibDiamond.contractOwner();
    }

    /// @notice checks if an address is an admin for the diamond
    /// @param _admin, address to check if its an admin
    function isAdmin(address _admin) external view returns (bool status_) {
        status_ = AccessControlStorage.accessControlStorage().adminAccount[_admin].status;
    }
}
