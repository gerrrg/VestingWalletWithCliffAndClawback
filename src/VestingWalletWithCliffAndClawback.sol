// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

contract VestingWalletWithCliffAndClawback is VestingWallet, Ownable2Step {

    error CurrentTimeIsBeforeCliff();
    error TokenCannotBeZeroAddress();
    error NoDirectEthTransfer();
    error ClawbackHasAlreadyOccurred();
    error ClawbackHasNotOccurred();

    uint256 private immutable _cliffDuration;

    // Track clawback variables for native asset
    bool private _clawbackHasOccurred;
    uint256 private _cumulativeReleasablePostClawback;

    // Track clawback variables for ERC20 tokens
    mapping(address => bool) private _clawbackHasOccurredErc20;
    mapping(address => uint256) private _cumulativeReleasablePostClawbackErc20;

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
    constructor(
        address owner,
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffDurationSeconds
    ) payable 
        Ownable2Step()
        VestingWallet(beneficiaryAddress, startTimestamp, durationSeconds)
    {
        _cliffDuration = cliffDurationSeconds;
        _transferOwnership(owner);
    }

    /**
     * @dev Getter for the vesting cliff duration.
     */
    function cliffDuration() public view virtual returns (uint256) {
        return _cliffDuration;
    }

    /**
     * @dev Getter for whether a native asset clawback has occurred.
     */
    function clawbackHasOccurred() public view virtual returns (bool) {
        return _clawbackHasOccurred;
    }

    /**
     * @dev Getter for whether a token clawback has occurred.
     */
    function clawbackHasOccurred(address token) public view virtual returns (bool) {
        return _clawbackHasOccurredErc20[token];
    }

    function clawback() public onlyOwner {
        if (clawbackHasOccurred()) {
            revert ClawbackHasAlreadyOccurred();
        }

        uint256 releasableNativeAsset = releasable();

        // Store the max cumulative payout to recipient after the the clawback has occurred
        // Need to store value as cumulative value because `release` only modifies `_released`
        _cumulativeReleasablePostClawback = released() + releasableNativeAsset;

        // Log that the clawback has occurred
        _clawbackHasOccurred = true;

        // Send current balance less current redeemable amount back to owner
        Address.sendValue(payable(owner()), address(this).balance - releasableNativeAsset);

    }

    function clawback(address token) public onlyOwner {
        if (clawbackHasOccurred(token)) {
            revert ClawbackHasAlreadyOccurred();
        }
        uint256 releasableErc20 = releasable(token);

        // Store the max cumulative payout to recipient after the the clawback has occurred
        // Need to store value as cumulative value because `release` only modifies `_erc20Released`
        _cumulativeReleasablePostClawbackErc20[token] = released(token) + releasableErc20;

        // Log that the clawback has occurred
        _clawbackHasOccurredErc20[token] = true;

        // Send current balance less current redeemable amount back to owner
        SafeERC20.safeTransfer(IERC20(token), owner(), IERC20(token).balanceOf(address(this)) - releasableErc20);
    }

    /**
     * @dev Override of getter for the amount of releasable eth to return 0 prior to meeting the cliff.
     */
    function releasable() public view override returns (uint256) {
        if (clawbackHasOccurred()) {
            return _cumulativeReleasablePostClawback - released();
        }
        if (_isBeforeCliff()) {
            return 0;
        }
        return super.releasable();
    }

    /**
     * @dev Override of getter for the amount of releasable `token` tokens to return 0 prior to meeting the cliff.
     * `token` should be the address of an IERC20 contract.
     */
    function releasable(address token) public view override returns (uint256) {
        if (clawbackHasOccurred(token)) {
            return _cumulativeReleasablePostClawbackErc20[token] - released(token);
        }
        if (_isBeforeCliff()) {
            return 0;
        }
        return super.releasable(token);
    }

    /**
     * @dev Release the native token (ether) that have already vested if the cliff has been passed.
     *
     * Emits a {EtherReleased} event.
     */
    function release() public override isAfterCliff {
        super.release();
    }

    /**
     * @dev Release the tokens that have already vested if the cliff has been passed.
     *
     * Emits a {ERC20Released} event.
     */
    function release(address token) public override isAfterCliff {
        super.release(token);
    }

    /**
     * @dev Allow owner to sweep native assets not redeemable by recipient after a clawback has occurred.
     *
     */
    function sweep() public onlyOwner {
        if (!clawbackHasOccurred()) {
            revert ClawbackHasNotOccurred();
        }
        Address.sendValue(payable(msg.sender), address(this).balance - releasable());
    }

    /**
     * @dev Allow owner to sweep tokens not redeemable by recipient after a clawback has occurred.
     *
     */
    function sweep(address token) public onlyOwner {
        if (!clawbackHasOccurred(token)) {
            revert ClawbackHasNotOccurred();
        }
        SafeERC20.safeTransfer(IERC20(token), msg.sender, IERC20(token).balanceOf(address(this)) - releasable(token));
    }

    /**
     * @dev Returns `true` if the current time is before the cliff.
     */
    function _isBeforeCliff() internal view virtual returns (bool) {
        return block.timestamp < (start() + cliffDuration());
    }
}
