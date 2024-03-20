// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import {VaultStorage} from "./storage/VaultStorage.sol";
import {IPinjamStrategy} from "./interfaces/IPinjamStrategy.sol";
import {Errors} from "../libraries/helpers/Errors.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

error InitializationFunctionReverted(
    address _initializationContractAddress,
    bytes _calldata
);

error SetHarvestOnDepositReverted(
    address _initializationContractAddress,
    bool _calldata
);

error SetCallFeeRecepientReverted(
    address _initializationContractAddress,
    address _calldata
);

error SetSlippageReverted(
    address _initializationContractAddress,
    uint256 _slippage
);

interface IPinjamVaultFacet {
    function delegatedViewBalanceOf(
        uint256 _index
    ) external view returns (uint256);

    function delegatedViewPendingRewards(
        uint256 _index
    ) external view returns (uint256[] memory);

    function delegatedViewGetHarvestOnDeposit(
        uint256 _index
    ) external view returns (bool);

    function delegatedViewGetStrategySource(
        uint256 _index
    ) external view returns (address);

    function delegatedViewGetCallFeeRecepient(
        uint256 _index
    ) external view returns (address);

    function delegatedViewGetSlippage(uint256 _index)
        external
        view
        returns (uint256);
}

contract PinjamVaultFacet {
    using SafeERC20 for IERC20;

    function addStrategySignature(
        VaultStorage.StrategyInfo memory _params
    ) external {
        LibDiamond.enforceIsContractOwner();

        VaultStorage.StrategyInfo[] storage strategies = VaultStorage
            .vaultStorage()
            .strategies;

        strategies.push(_params);
        VaultStorage.vaultStorage().strategyCount += 1;
    }

    function changeStrategyAddress(
        uint256 _index,
        address _newStrategyAddress
    ) external {
        LibDiamond.enforceIsContractOwner();

        VaultStorage.StrategyInfo[] storage strategies = VaultStorage
            .vaultStorage()
            .strategies;

        require(_index < strategies.length, "Invalid index");
        require(
            strategies[_index].strategy != _newStrategyAddress,
            "Same strategy address"
        );
        require(
            _newStrategyAddress != address(0),
            "New strategy address cannot be 0"
        );

        strategies[_index].strategy = _newStrategyAddress;
    }

    // external deposit will default to deposit into the first strategy
    function deposit() external {
        VaultStorage._onlyPToken();
        _deposit(VaultStorage.vaultStorage().defaultStrategyIndex);
    }

    function _deposit(uint256 _index) internal {
        // Tokens should be deposited to vault
        uint256 bal = balanceOfWant();
        if (bal == 0) return;

        VaultStorage.StrategyInfo memory strat = VaultStorage
            .vaultStorage()
            .strategies[_index];

        if (strat.paused) {
            return;
        }

        (bool success, bytes memory data) = strat.strategy.delegatecall(
            abi.encodeWithSignature("deposit(uint256)", bal)
        );

        if (!success) {
            if (data.length == 0)
                revert(
                    "PinjamVaultFacet::deposit: Transaction execution reverted."
                );
            assembly {
                revert(add(32, data), mload(data))
            }
        }
    }

    function withdraw(address _to, uint256 _amount) external {
        VaultStorage._onlyPToken();

        uint256 wantBalance = balanceOfWant();
        uint256 totalWithdrawed;

        if (wantBalance > _amount) {
            IERC20(VaultStorage.vaultStorage().want).safeTransfer(_to, _amount);
            return;
        }

        uint256 strategyCount = VaultStorage.vaultStorage().strategyCount;
        for (uint256 i; i < strategyCount; i++) {
            totalWithdrawed += _withdraw(i, _to, _amount - totalWithdrawed);

            if (totalWithdrawed >= _amount) {
                break;
            }
        }

        // if amount is more than totalWithdrawed,
        // then assume remaining balance is in vault and transfer to `_to`
        if (_amount > totalWithdrawed) {
            IERC20(VaultStorage.vaultStorage().want).safeTransfer(
                _to,
                _amount - totalWithdrawed
            );
        }

        // Assumes required amount has been withdrawn, any remaining balance will be put back to work
        if (!VaultStorage.vaultStorage().strategiesFrozen) {
            _deposit(VaultStorage.vaultStorage().defaultStrategyIndex);
        }
    }

    function _withdraw(
        uint256 _index,
        address _to,
        uint256 _amount
    ) internal returns (uint256 bal) {
        VaultStorage.StrategyInfo memory strat = VaultStorage
            .vaultStorage()
            .strategies[_index];

        (bool success, bytes memory data) = strat.strategy.delegatecall(
            abi.encodeWithSignature("withdraw(address,uint256)", _to, _amount)
        );

        if (!success) {
            if (data.length == 0)
                revert(
                    "PinjamVaultFacet::withdraw: Transaction execution reverted."
                );
            assembly {
                revert(add(32, data), mload(data))
            }
        }

        bal = uint256(bytes32(data));
    }

    function harvest(uint256 _index) external {
        // Tokens should be deposited to vault

        VaultStorage.StrategyInfo memory strat = VaultStorage
            .vaultStorage()
            .strategies[_index];

        bytes memory callData = abi.encodeWithSignature("harvest()");
        (bool success, bytes memory res) = strat.strategy.delegatecall(
            callData
        );

        if (!success) {
            if (res.length == 0)
                revert(
                    "PinjamVaultFacet::harvest: Transaction execution reverted."
                );
            assembly {
                revert(add(32, res), mload(res))
            }
        }
    }

    /// @notice Rebalances assets from one strategy to the other
    function rebalance(
        uint256 _fromIndex,
        uint256 _toIndex,
        uint256 _amount
    ) external {
        LibDiamond.enforceIsContractOwner();
        _withdraw(_fromIndex, address(this), _amount);
        _deposit(_toIndex);
    }

    function initStrategy(address _init, bytes memory _calldata) external {
        LibDiamond.enforceIsContractOwner();

        if (_init == address(0)) {
            return;
        }

        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }
    }

    function want() external view returns (address) {
        return VaultStorage.vaultStorage().want;
    }

    function parseDelegatedView(
        uint256 _index,
        string memory _signature
    ) internal returns (bytes memory) {
        (bool success, bytes memory res) = VaultStorage
            .vaultStorage()
            .strategies[_index]
            .strategy
            .delegatecall(abi.encodeWithSignature(_signature));

        if (!success) {
            if (res.length == 0) revert();
            assembly {
                revert(add(32, res), mload(res))
            }
        }
        return res;
    }

    /// @notice calls external contracts view function which returns uint256 values
    /// @notice Should only be called by self.
    function delegatedViewBalanceOf(uint256 _index) external returns (uint256) {
        require(msg.sender == address(this));

        bytes memory res = parseDelegatedView(_index, "balanceOf()");
        return abi.decode(res, (uint256));
    }

    function delegatedViewPendingRewards(
        uint256 _index
    ) external returns (uint256[] memory) {
        require(msg.sender == address(this));

        bytes memory res = parseDelegatedView(_index, "pendingRewards()");
        return abi.decode(res, (uint256[]));
    }

    function delegatedViewGetHarvestOnDeposit(
        uint256 _index
    ) external returns (bool) {
        require(msg.sender == address(this));

        bytes memory res = parseDelegatedView(_index, "getHarvestOnDeposit()");
        return abi.decode(res, (bool));
    }

    function delegatedViewGetStrategySource(
        uint256 _index
    ) external returns (address) {
        require(msg.sender == address(this));

        bytes memory res = parseDelegatedView(_index, "getStrategySource()");
        return abi.decode(res, (address));
    }

    function delegatedViewGetCallFeeRecepient(
        uint256 _index
    ) external returns (address) {
        require(msg.sender == address(this));

        bytes memory res = parseDelegatedView(
            _index,
            "getCallFeeRecepient()"
        );
        return abi.decode(res, (address));
    }

    function delegatedViewGetSlippage(uint256 _index)
        external
        returns (uint256)
    {
        require(msg.sender == address(this));

        bytes memory res = parseDelegatedView(_index, "getSlippage()");
        return abi.decode(res, (uint256));
    }

    function getSlippage(uint256 _index) external view returns (uint256) {
        return IPinjamVaultFacet(address(this)).delegatedViewGetSlippage(_index);
    }

    function getCallFeeRecepient(uint256 _index)
        external
        view
        returns (address)
    {
        return IPinjamVaultFacet(address(this)).delegatedViewGetCallFeeRecepient(_index);
    }
    
    function balance() external view returns (uint256 bal) {
        uint256 strategyCount = VaultStorage.vaultStorage().strategyCount;

        // Adds up all strategy balance
        for (uint256 i; i < strategyCount; i++) {
            bal += IPinjamVaultFacet(address(this)).delegatedViewBalanceOf(i);
        }

        // Adds up remaining balance sitting in vault
        bal += balanceOfWant();
    }

    function strategyBalance(
        uint256 _index
    ) external view returns (uint256 bal_) {
        bal_ = IPinjamVaultFacet(address(this)).delegatedViewBalanceOf(_index);
    }

    function strategyPendingRewards(
        uint256 _index
    ) external view returns (uint256[] memory bal_) {
        bal_ = IPinjamVaultFacet(address(this)).delegatedViewPendingRewards(
            _index
        );
    }

    // Returns idle balance of `want` token in the vault contract
    function balanceOfWant() public view returns (uint256) {
        return
            IERC20(VaultStorage.vaultStorage().want).balanceOf(address(this));
    }

    function inCaseTokensGetStuck(address _to, address _token) external {
        LibDiamond.enforceIsContractOwner();
        require(
            _token != address(VaultStorage.vaultStorage().want),
            "!wantToken"
        );

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(_to, amount);
    }

    function setPToken(address _token) external {
        LibDiamond.enforceIsContractOwner();
        VaultStorage.vaultStorage().pToken = _token;
    }

    function setWant(address _want) external {
        LibDiamond.enforceIsContractOwner();
        VaultStorage.vaultStorage().want = _want;
    }

    function setHarvestOnDeposit(uint256 _index, bool _onDeposit) external {
        LibDiamond.enforceIsContractOwner();

        (bool success, bytes memory error) = VaultStorage
            .vaultStorage()
            .strategies[_index]
            .strategy
            .delegatecall(
                abi.encodeWithSignature("setHarvestOnDeposit(bool)", _onDeposit)
            );

        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert SetHarvestOnDepositReverted(
                    VaultStorage.vaultStorage().strategies[_index].strategy,
                    _onDeposit
                );
            }
        }
    }

    function setCallFeeRecepient(
        uint256 _index,
        address _callFeeRecipient
    ) external {
        LibDiamond.enforceIsContractOwner();

        (bool success, bytes memory error) = VaultStorage
            .vaultStorage()
            .strategies[_index]
            .strategy
            .delegatecall(
                abi.encodeWithSignature("setCallFeeRecepient(address)", _callFeeRecipient)
            );

        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert SetCallFeeRecepientReverted(
                    VaultStorage.vaultStorage().strategies[_index].strategy,
                    _callFeeRecipient
                );
            }
        }
    }

    function setSlippage(
        uint256 _index,
        uint256 _slippage
    ) external {
        LibDiamond.enforceIsContractOwner();

        (bool success, bytes memory error) = VaultStorage
            .vaultStorage()
            .strategies[_index]
            .strategy
            .delegatecall(
                abi.encodeWithSignature("setSlippage(uint256)", _slippage)
            );

        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert SetSlippageReverted(
                    VaultStorage.vaultStorage().strategies[_index].strategy,
                    _slippage
                );
            }
        }
    }

    function setPaused(uint256 _index, bool _paused) external {
        LibDiamond.enforceIsContractOwner();
        VaultStorage.vaultStorage().strategies[_index].paused = _paused;
    }

    function setDefaultStrategyIndex(uint256 _defaultStrategyIndex) external {
        LibDiamond.enforceIsContractOwner();
        VaultStorage
            .vaultStorage()
            .defaultStrategyIndex = _defaultStrategyIndex;
    }

    function setStrategiesFrozen(bool _strategiesFrozen) external {
        LibDiamond.enforceIsContractOwner();
        VaultStorage.vaultStorage().strategiesFrozen = _strategiesFrozen;
    }

    function getStrategiesFrozen() external view returns (bool) {
        return VaultStorage.vaultStorage().strategiesFrozen;
    }

    function getPToken() external view returns (address) {
        return VaultStorage.vaultStorage().pToken;
    }

    function getWant() external view returns (address) {
        return VaultStorage.vaultStorage().want;
    }

    function _strategyYieldSource(
        uint256 _index
    ) internal view returns (address) {
        return
            IPinjamVaultFacet(address(this)).delegatedViewGetStrategySource(
                _index
            );
    }

    function getStrategyInfo(
        uint256 _index
    )
        external
        view
        returns (
            address strategy_,
            address yieldSource_,
            bool paused_,
            bool harvestOnDeposit_,
            uint256 defaultStrategyIndex_
        )
    {
        VaultStorage.StrategyInfo memory strat = VaultStorage
            .vaultStorage()
            .strategies[_index];
        yieldSource_ = _strategyYieldSource(_index);

        strategy_ = strat.strategy;
        paused_ = strat.paused;
        harvestOnDeposit_ = IPinjamVaultFacet(address(this))
            .delegatedViewGetHarvestOnDeposit(_index);

        defaultStrategyIndex_ = VaultStorage
            .vaultStorage()
            .defaultStrategyIndex;
    }

    function getTotalStrategies() external view returns (uint256) {
        return VaultStorage.vaultStorage().strategyCount;
    }
}
