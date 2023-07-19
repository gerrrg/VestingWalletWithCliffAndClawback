// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";

/**
 * @title VestingWalletWithCliff
 * @dev This contract builds on OpenZeppelin's VestingWallet. See comments in VestingWallet for base details.
 *
 * This contract adds the following functionality:
 *   - Add a vesting cliff: `recipient` cannot claim any vested tokens until a cliff duration has elapsed
 */
abstract contract VestingWalletWithCliff is VestingWallet {

    error CurrentTimeIsBeforeCliff();

    uint64 private immutable _cliffDuration;

    /**
     * @dev Set the cliff and owner.
     * @dev Set the beneficiary, start timestamp, and vesting duration within VestingWallet base class.
     */
    constructor(uint64 cliffDurationSeconds)
    {
        _cliffDuration = cliffDurationSeconds;
    }

    /**
     * @dev Getter for the vesting cliff duration.
     */
    function cliffDuration() public view virtual returns (uint256) {
        return _cliffDuration;
    }

    /**
     * @dev Override of VestingWallet's `_vestingSchedule` to enforce releasing nothing until the cliff has passed.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        if (_isBeforeCliff()) {
            return 0;
        }
        return super._vestingSchedule(totalAllocation, timestamp);
    }

    /**
     * @dev Returns `true` if the current time is before the cliff.
     */
    function _isBeforeCliff() internal view returns (bool) {
        return uint64(block.timestamp) < (start() + cliffDuration());
    }
}
