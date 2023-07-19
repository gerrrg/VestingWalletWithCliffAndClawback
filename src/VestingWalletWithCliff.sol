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

    uint256 private immutable _cliffDuration;

    modifier isAfterCliff() {
        if (_isBeforeCliff()) {
            revert CurrentTimeIsBeforeCliff();
        }
        _;
    }

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
     * @dev Override of getter for the amount of releasable native assets to return 0 prior to meeting the cliff.
     */
    function releasable() public view virtual override returns (uint256) {
        if (_isBeforeCliff()) {
            return 0;
        }
        return super.releasable();
    }

    /**
     * @dev Override of getter for the amount of releasable `token` tokens to return 0 prior to meeting the cliff.
     * `token` should be the address of an IERC20 contract.
     */
    function releasable(address token) public view virtual override returns (uint256) {
        if (_isBeforeCliff()) {
            return 0;
        }
        return super.releasable(token);
    }

    /**
     * @dev Release the native assets that have already vested if the cliff has been passed.
     *
     * Emits a {EtherReleased} event.
     */
    function release() public virtual override isAfterCliff {
        super.release();
    }

    /**
     * @dev Release the tokens that have already vested if the cliff has been passed.
     *
     * Emits a {ERC20Released} event.
     */
    function release(address token) public virtual override isAfterCliff {
        super.release(token);
    }

    /**
     * @dev Returns `true` if the current time is before the cliff.
     */
    function _isBeforeCliff() internal view returns (bool) {
        return block.timestamp < (start() + cliffDuration());
    }
}
