// SPDX-License-Identifier: BUSL 1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VaultStorage} from "../../storage/VaultStorage.sol";
import {ACryptosMareStrategyStorage} from "./storage/ACryptosMareStrategyStorage.sol";
import {IPinjamStrategy} from "../../interfaces/IPinjamStrategy.sol";

import "hardhat/console.sol";

interface IACryptosMareVault {
    function deposit(uint256 _amount) external;

    function withdraw(uint256 _shares) external;

    function harvest() external;

    function getPricePerFullShare() external view returns (uint256);

    function balance() external view returns (uint256);
}

contract ACryptosMareStrategy is IPinjamStrategy {
    using SafeERC20 for IERC20;

    function init(
        ACryptosMareStrategyStorage.StorageLayout memory _stratInit
    ) external {
        ACryptosMareStrategyStorage.init(_stratInit);

        IERC20(VaultStorage.vaultStorage().want).safeApprove(
            ACryptosMareStrategyStorage.strategyStorage().source,
            type(uint256).max
        );
    }

    function _beforeDeposit() internal override {
        if (ACryptosMareStrategyStorage.strategyStorage().harvestOnDeposit) {
            _harvest();
        }
    }

    function deposit(uint256 _amount) public override {
        _beforeDeposit();
        console.log(
            "balance before deposit",
            IERC20(VaultStorage.vaultStorage().want).balanceOf(address(this))
        );
        IACryptosMareVault(ACryptosMareStrategyStorage.strategyStorage().source)
            .deposit(_amount);
        console.log(
            "balance before withdraw",
            IERC20(VaultStorage.vaultStorage().want).balanceOf(address(this))
        );
        IACryptosMareVault(ACryptosMareStrategyStorage.strategyStorage().source)
            .withdraw(
                IERC20(ACryptosMareStrategyStorage.strategyStorage().source)
                    .balanceOf(address(this))
            );

        console.log(
            "balance after withdraw",
            IERC20(VaultStorage.vaultStorage().want).balanceOf(address(this))
        );
        emit Deposit(_amount);
    }

    function withdraw(
        address _to,
        uint256 _amount
    ) public override returns (uint256) {
        uint256 availBalance = balanceOf();

        if (availBalance == 0) return 0;

        if (_amount > availBalance) {
            _amount = availBalance;
        }

        IACryptosMareVault(ACryptosMareStrategyStorage.strategyStorage().source)
            .withdraw(_amount);

        emit Withdraw(_to, _amount);
        return _amount;
    }

    function harvest() external override {
        _harvest();
    }

    function _harvest() internal override {}

    // The sum of balanceOfPool
    function balanceOf() public view override returns (uint256) {
        console.log(
            "acryptos Balance",
            IACryptosMareVault(
                ACryptosMareStrategyStorage.strategyStorage().source
            ).balance()
        );

        console.log(
            "getPricePerFullShare",
            IACryptosMareVault(
                ACryptosMareStrategyStorage.strategyStorage().source
            ).getPricePerFullShare()
        );

        console.log(
            "deposited balance",
            (IERC20(ACryptosMareStrategyStorage.strategyStorage().source)
                .balanceOf(address(this)) *
                IACryptosMareVault(
                    ACryptosMareStrategyStorage.strategyStorage().source
                ).getPricePerFullShare()) / 1e18
        );

        return
            IERC20(ACryptosMareStrategyStorage.strategyStorage().source)
                .balanceOf(address(this));
    }

    function pendingRewards() public view override returns (uint256[] memory) {
        address[] memory assets = new address[](1);
        // assets[0] = ACryptosMareStrategyStorage.strategyStorage().aToken;
        uint256[] memory bal = new uint256[](1);

        // bal[0] = IAaveV3Incentives(AAVE_INCENTIVES_CONTROLLER).getUserRewards(
        //     assets,
        //     address(this),
        //     NATIVE_WRAPPED_TOKEN
        // );

        return bal;
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external override {
        ACryptosMareStrategyStorage
            .strategyStorage()
            .harvestOnDeposit = _harvestOnDeposit;
    }

    function getHarvestOnDeposit()
        external
        view
        override
        returns (bool harvestOnDeposit_)
    {
        harvestOnDeposit_ = ACryptosMareStrategyStorage
            .strategyStorage()
            .harvestOnDeposit;
    }

    function getStrategySource()
        external
        view
        override
        returns (address yieldSource_)
    {
        yieldSource_ = ACryptosMareStrategyStorage.strategyStorage().source;
    }
}
