// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseVestingWalletFactory.sol";

/**
 * @title OpinionatedVestingWalletFactory
 * @dev Factory for VestingWalletWithCliffAndClawback. See VestingWalletWithCliffAndClawback.sol for details.
 *      This factory creates wallets with 4-year vesting and a 1-year cliff.
 */
contract OpinionatedVestingWalletFactory is BaseVestingWalletFactory {

    /**
     * @dev Creates a new VestingWalletWithCliffAndClawback with 4-year vesting and 1-year cliff.
     */
    function create(
        address ownerAddress,
        address beneficiaryAddress,
        uint64 startTimestamp
    ) public virtual returns (address) {
        return _create(
            ownerAddress,
            beneficiaryAddress,
            startTimestamp,
            4 * 52 weeks, // `years` and `months` are deprecated
            52 weeks
        );
    }
}
