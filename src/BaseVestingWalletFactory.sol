// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./VestingWalletWithCliffAndClawback.sol";

/**
 * @title BaseVestingWalletFactory
 * @dev Factory infra for VestingWalletWithCliffAndClawback. See VestingWalletWithCliffAndClawback.sol for details.
 *      Inherit this from specific factories.
 */
abstract contract BaseVestingWalletFactory {

    event VestingWalletCreated(
        address indexed walletAddress,
        address indexed ownerAddress,
        address indexed beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffDurationSeconds
    );

    mapping(address => bool) private _isWalletFromFactory;

    /**
     * @dev Creates, logs, and registers a new VestingWalletWithCliffAndClawback.
     */
    function _create(
        address ownerAddress,
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffDurationSeconds
    ) internal virtual returns (address) {
        VestingWalletWithCliffAndClawback wallet = new VestingWalletWithCliffAndClawback(
            ownerAddress,
            beneficiaryAddress,
            startTimestamp,
            durationSeconds,
            cliffDurationSeconds
        );
        
        // Log publicly
        emit VestingWalletCreated(
            address(wallet),
            ownerAddress,
            beneficiaryAddress,
            startTimestamp,
            durationSeconds,
            cliffDurationSeconds
        );
        
        // Log locally
        _isWalletFromFactory[address(wallet)] = true;
        
        return address(wallet);
    }

    /**
     * @dev Returns `true` if given `wallet` was created by this factory.
     */
    function isWalletFromFactory(address wallet) external view returns (bool) {
        return _isWalletFromFactory[wallet];
    }
}
