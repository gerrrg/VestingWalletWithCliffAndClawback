// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

/**
 * @title VestingWalletWithClawback
 * @dev This contract builds on OpenZeppelin's VestingWallet. See comments in VestingWallet for base details.
 *
 * This contract adds the following functionality:
 *   - Add `owner`: contract is `Ownable2Step`
 *   - Add clawbacks: contract `owner` can clawback any unvested tokens
 *   - Add post-clawback sweeps: contract `owner` can sweep any excess tokens sent to the contract after clawback
 */
abstract contract VestingWalletWithClawback is VestingWallet, Ownable2Step {

    event ERC20ClawedBack(address indexed token, uint256 amount);
    event ERC20Swept(address indexed token, uint256 amount);
    event EtherClawedBack(uint256 amount);
    event EtherSwept(uint256 amount);

    error ClawbackHasAlreadyOccurred();
    error ClawbackHasNotOccurred();

    // Track clawback variables for native asset
    bool private _clawbackHasOccurred;
    uint256 private _cumulativeReleasablePostClawback;

    // Track clawback variables for ERC20 tokens
    mapping(address => bool) private _erc20ClawbackHasOccurred;
    mapping(address => uint256) private _erc20CumulativeReleasablePostClawback;

    /**
     * @dev Set the owner.
     */
    constructor(address ownerAddress)
        Ownable2Step()
    {
        _transferOwnership(ownerAddress);
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
        return _erc20ClawbackHasOccurred[token];
    }

    /**
     * @dev Allow owner to clawback unvested native assets from contract.
     *
     * Emits an {EtherClawedBack} event.
     */
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
        uint256 amount = address(this).balance - releasableNativeAsset;
        Address.sendValue(payable(msg.sender), amount);
        emit EtherClawedBack(amount);
    }

    /**
     * @dev Allow owner to clawback unvested ERC20 tokens from contract.
     *
     * Emits an {ERC20ClawedBack} event.
     */
    function clawback(address token) public onlyOwner {
        if (clawbackHasOccurred(token)) {
            revert ClawbackHasAlreadyOccurred();
        }
        uint256 releasableErc20 = releasable(token);

        // Store the max cumulative payout to recipient after the the clawback has occurred
        // Need to store value as cumulative value because `release` only modifies `_erc20Released`
        _erc20CumulativeReleasablePostClawback[token] = released(token) + releasableErc20;

        // Log that the clawback has occurred
        _erc20ClawbackHasOccurred[token] = true;

        // Send current balance less current redeemable amount back to owner
        uint256 amount = IERC20(token).balanceOf(address(this)) - releasableErc20;
        SafeERC20.safeTransfer(IERC20(token), msg.sender, amount);
        emit ERC20ClawedBack(token, amount);
    }

    /**
     * @dev Override of getter for the amount of releasable native assets to handle releasing vested
     * assets after a clawback.
     */
    function releasable() public view virtual override returns (uint256) {
        if (clawbackHasOccurred()) {
            return _cumulativeReleasablePostClawback - released();
        }
        return super.releasable();
    }

    /**
     * @dev Override of getter for the amount of releasable `token` tokens to handle releasing vested
     * assets after a clawback. `token` should be the address of an IERC20 contract.
     */
    function releasable(address token) public view virtual override returns (uint256) {
        if (clawbackHasOccurred(token)) {
            return _erc20CumulativeReleasablePostClawback[token] - released(token);
        }
        return super.releasable(token);
    }

    /**
     * @dev Allow owner to sweep native assets not redeemable by recipient after a clawback has occurred.
     *
     * Emits a {EtherSwept} event.
     */
    function sweep() public onlyOwner {
        if (!clawbackHasOccurred()) {
            revert ClawbackHasNotOccurred();
        }

        // Sweep current balance less current redeemable amount back to owner
        uint256 amount = address(this).balance - releasable();
        Address.sendValue(payable(msg.sender), amount);
        emit EtherSwept(amount);
    }

    /**
     * @dev Allow owner to sweep tokens not redeemable by recipient after a clawback has occurred.
     *
     * Emits a {ERC20Swept} event.
     */
    function sweep(address token) public onlyOwner {
        if (!clawbackHasOccurred(token)) {
            revert ClawbackHasNotOccurred();
        }

        // Sweep current balance less current redeemable amount back to owner
        uint256 amount = IERC20(token).balanceOf(address(this)) - releasable(token);
        SafeERC20.safeTransfer(IERC20(token), msg.sender, amount);
        emit ERC20Swept(token, amount);
    }
}
