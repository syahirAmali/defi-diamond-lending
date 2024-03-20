// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.17;

/**
 * @title IPinjamOracle
 * @author
 * @notice Defines the basic interface for the Pinjam Oracle
 */
interface IPinjamOracle {
    /**
     * @dev Emitted after the price source of an asset is updated
     * @param asset The address of the asset
     * @param source The price source of the asset
     */
    event AssetSourceUpdated(address indexed asset, address indexed source);

    //   /**
    //    * @notice Returns the PoolAddressesProvider
    //    * @return The address of the PoolAddressesProvider contract
    //    */
    //   function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

    /**
     * @notice Sets or replaces price sources of assets
     * @param assets The addresses of the assets
     * @param sources The addresses of the price sources
     */
    function setAssetSources(
        address[] calldata assets,
        address[] calldata sources
    ) external;

    /**
     * @notice Returns the asset price in the base currency
     * @param asset The address of the asset
     * @return The price of the asset
     **/
    function getAssetPrice(address asset) external view returns (uint256);

    /**
     * @notice Returns a list of prices from a list of assets addresses
     * @param assets The list of assets addresses
     * @return The prices of the given assets
     */
    function getAssetsPrices(address[] calldata assets)
        external
        view
        returns (uint256[] memory);

    /**
     * @notice Returns the address of the source for an asset address
     * @param asset The address of the asset
     * @return The address of the source
     */
    function getSourceOfAsset(address asset) external view returns (address);
}
