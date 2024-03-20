// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {AddressRegistryStorage} from "./storage/AddressRegistryStorage.sol";
import {AccessControlStorage} from "../AccessControlFacet/storage/AccessControlStorage.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";

contract AddressRegistryFacet {
    //***************************************************************//
    //  Address Registry Facet                                       //
    //***************************************************************//

    //**Events*******************************************************//
    event SetAddressRegistry(address indexed _registry);
    event SetAccessControl(address indexed _accessControl);
    event SetDiamondCut(address indexed _diamondCut);
    event SetDiamondLoupe(address indexed _loupe);
    event SetOracle(address indexed _oracle);
    event SetPoolManager(address indexed _poolManager);
    event SetPToken(address indexed _pToken);
    event SetDebtToken(address indexed _debtToken);
    event SetPool(address indexed _pool);
    event SetTokenManager(address indexed _tokenManager);
    event SetPoolFactory(address indexed _poolFactory);
    event SetPoolData(address indexed _poolData);

    //**Setters******************************************************//

    /// @notice Sets the address registry address implementation
    /// @param _registry, address of the registry deployed
    function setAddressRegistry(address _registry) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().addressRegistry = _registry;

        emit SetAddressRegistry(_registry);
    }

    /// @notice Sets the access control address implementation
    /// @param _accessControl, address of the access control deployed
    function setAccessControl(address _accessControl) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().accessControl = _accessControl;

        emit SetAccessControl(_accessControl);
    }

    /// @notice Sets the diamond cut address implementation
    /// @param _cut, address of the diamond cut deployed
    function setDiamondCut(address _cut) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().diamondCut = _cut;

        emit SetDiamondCut(_cut);
    }

    /// @notice Sets the diamond loupe address implementation
    /// @param _loupe, address of the diamond loupe deployed
    function setDiamondLoupe(address _loupe) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().diamondLoupe = _loupe;
        
        emit SetDiamondLoupe(_loupe);
    }

    /// @notice Sets the oracle address implementation
    /// @param _oracle, address of the oracle deployed
    function setOracle(address _oracle) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().oracle = _oracle;
        
        emit SetOracle(_oracle);
    }

    /// @notice Sets the pool manager address implementation
    /// @param _poolManager, address of the pool manager deployed
    function setPoolManager(address _poolManager) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().poolManager = _poolManager;
        
        emit SetPoolManager(_poolManager);
    }

    /// @notice Sets the pToken address implementation
    /// @param _pToken, address of the pToken deployed
    function setPToken(address _pToken) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().pToken = _pToken;
        
        emit SetPToken(_pToken);
    }

    /// @notice Sets the debtToken address implementation
    /// @param _debtToken, address of the debtToken deployed
    function setDebtToken(address _debtToken) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().debtToken = _debtToken;
        
        emit SetDebtToken(_debtToken);
    }

    /// @notice Sets the pool address implementation
    /// @param _pool, address of the pool deployed
    function setPool(address _pool) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().pool = _pool;

        emit SetPool(_pool);
    }

    /// @notice Sets the token manager address implementation
    /// @param _tokenManager, address of the token manager deployed
    function setTokenManager(address _tokenManager) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().tokenManager = _tokenManager;

        emit SetTokenManager(_tokenManager);
    }

    /// @notice Sets the pool factory address implementation
    /// @param _poolFactory, address of the pool factory deployed
    function setPoolFactory(address _poolFactory) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().poolFactory = _poolFactory;

        emit SetPoolFactory(_poolFactory);
    }

    /// @notice Sets the pool factory address implementation
    /// @param _poolData, address of the pool factory deployed
    function setPoolData(address _poolData) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().poolData = _poolData;

        emit SetPoolData(_poolData);
    }

    function setWethGateway(address _wethGateway) external {
        LibDiamond.enforceIsContractOwner();
        AddressRegistryStorage.registryStorage().wethGateway = _wethGateway;
    }

    //**Getters******************************************************//

    /// @notice gets the address registry implementation address
    function getAddressRegistry() external view returns (address registry_){
        registry_ = AddressRegistryStorage.registryStorage().addressRegistry;
    }

    /// @notice gets the access control implementation address
    function getAccessControl() external view returns (address accessControl_) {
        accessControl_ = AddressRegistryStorage.registryStorage().accessControl;
    }

    /// @notice gets the diamond cut implementation address
    function getDiamondCut() external view returns (address cut_){
        cut_ = AddressRegistryStorage.registryStorage().diamondCut;
    }

    /// @notice gets the diamond loupe implementation address
    function getDiamondLoupe() external view returns (address loupe_){
        loupe_ = AddressRegistryStorage.registryStorage().diamondLoupe;
    }

    /// @notice gets the oracle implementation address
    function getOracle() external view returns (address oracle_){
        oracle_ = AddressRegistryStorage.registryStorage().oracle;
    }

    /// @notice gets the pool manager implementation address
    function getPoolManager() external view returns (address poolManager_){
        poolManager_ = AddressRegistryStorage.registryStorage().poolManager;
    }

    /// @notice gets the pToken implementation address
    function getPToken() external view returns (address pToken_){
        pToken_ = AddressRegistryStorage.registryStorage().pToken;
    }

    /// @notice gets the debtToken implementation address
    function getDebtToken() external view returns (address debtToken_){
        debtToken_ = AddressRegistryStorage.registryStorage().debtToken;
    }

    /// @notice gets the pool implementation address
    function getPool() external view returns (address pool_){
        pool_ = AddressRegistryStorage.registryStorage().pool;
    }

    /// @notice gets the token manager implementation address
    function getTokenManager() external view returns (address tokenManager_){
        tokenManager_ = AddressRegistryStorage.registryStorage().tokenManager;
    }

    /// @notice gets the pool factory implementation address
    function getPoolFactory() external view returns (address poolFactory_){
        poolFactory_ = AddressRegistryStorage.registryStorage().poolFactory;
    }

    /// @notice gets the pool factory implementation address
    function getPoolData() external view returns (address poolData_){
        poolData_ = AddressRegistryStorage.registryStorage().poolData;
    }

    function getWethGateway() external view returns (address wethGateway_) {
        wethGateway_ = AddressRegistryStorage.registryStorage().wethGateway;
    }
}
