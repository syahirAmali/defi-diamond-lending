// SPDX-License-Identifier: BUSL 1.1
import {DataTypes} from "../../../libraries/types/DataTypes.sol";
pragma solidity ^0.8.0;

library PoolManagerStorage {
    //**Storage******************************************************//

    bytes32 private constant POOL_STORAGE_POSITION =
        keccak256("diamond.standard.pool.storage");

    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    /**
     * @dev Default percentage of borrower's debt to be repaid in a liquidation.
     * @dev Percentage applied when the users health factor is above `CLOSE_FACTOR_HF_THRESHOLD`
     * Expressed in bps, a value of 0.5e4 results in 50.00%
     */
    uint256 internal constant DEFAULT_LIQUIDATION_CLOSE_FACTOR = 0.5e4;

    /**
     * @dev Maximum percentage of borrower's debt to be repaid in a liquidation
     * @dev Percentage applied when the users health factor is below `CLOSE_FACTOR_HF_THRESHOLD`
     * Expressed in bps, a value of 1e4 results in 100.00%
     */
    uint256 public constant MAX_LIQUIDATION_CLOSE_FACTOR = 1e4;

    /**
     * @dev This constant represents below which health factor value it is possible to liquidate
     * an amount of debt corresponding to `MAX_LIQUIDATION_CLOSE_FACTOR`.
     */
    uint256 public constant CLOSE_FACTOR_HF_THRESHOLD = 0.95 ether;

    /**
     * @dev This represents is the minimum Health Factor for an account to be liquidated.
     */
    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1 ether;

    /**
     * @dev The % to be used to pay depositors to work funds out of total accrued farming fees
     */
    uint256 public constant VAULT_DEPOSIT_FEES = 500; // 5%

    function poolManagerStorage()
        internal
        pure
        returns (DataTypes.PoolStorage storage ps)
    {
        bytes32 position = POOL_STORAGE_POSITION;
        assembly {
            ps.slot := position
        }
    }
}
