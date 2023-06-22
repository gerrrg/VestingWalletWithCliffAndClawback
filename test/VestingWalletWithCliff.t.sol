// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "../src/VestingWalletWithCliff.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract VestingWalletWithCliffTest is Test {
    VestingWalletWithCliff public wallet;

    // Foundry does not handle overloaded functions well at all.
    // Manually entering the function selectors here is the easiest workaround.
    bytes4 constant releaseSelector = "\x86\xd1\xa6\x9f";
    bytes4 constant releaseAddressSelector = "\x19\x16\x55\x87";

    address provider = vm.addr(0x1);
    address recipient = vm.addr(0x2);
    ERC20 fakeToken;

    uint256 amountDeposit = 1e18;

    uint64 startDelay = 10;
    uint64 vestDuration = 40;
    uint64 cliffDuration = 10;

    function _assertReleasableIsAmount(uint256 amount) internal view {
        assert(wallet.releasable() == amount);
        assert(wallet.releasable(address(fakeToken)) == amount);
    }

    function _assertAbilityToRelease(bool expectedSuccess) internal {
        bool success;
        bytes memory data;

        (success, data) = address(wallet).call(abi.encodeWithSelector(releaseSelector));
        assert(success == expectedSuccess);

        (success, data) = address(wallet).call(abi.encodeWithSelector(releaseAddressSelector, address(fakeToken)));
        assert(success == expectedSuccess);
    }

    function setUp() public {
        uint64 startTime = uint64(block.timestamp) + startDelay;
        wallet = new VestingWalletWithCliff(recipient, startTime, vestDuration, cliffDuration);
        vm.deal(provider, 1000 ether);
        vm.deal(recipient, 1 ether);

        fakeToken = new ERC20("Fake Token","FAKE");
        deal(address(fakeToken), provider, amountDeposit);

        vm.prank(provider);
        (bool success, ) = address(wallet).call{value: amountDeposit}("");
        assert(success);
        assert(amountDeposit == address(wallet).balance);

        vm.prank(provider);
        fakeToken.transfer(address(wallet), amountDeposit);
        assert(amountDeposit == fakeToken.balanceOf(address(wallet)));
    }

    function testCliffDuration() view public {
        assert(wallet.cliffDuration() == cliffDuration);
    }

    function testPreCliffReleasableZero() view public {
        _assertReleasableIsAmount(0);
    }

    function testReleasableDuringCliffZero() public {
        skip(startDelay);
        _assertReleasableIsAmount(0);

        skip(cliffDuration - 1);
        _assertReleasableIsAmount(0);
    }

    function testCannotReleaseDuringCliff() public {
        skip(startDelay);
        _assertAbilityToRelease(false);

        skip(cliffDuration - 1);
        _assertAbilityToRelease(false);
    }


    function testReleasableAfterCliffNonZero() public {
        skip(startDelay + cliffDuration);
        uint256 amount;
        for (uint256 i = startDelay + cliffDuration; i < startDelay + vestDuration; i++) {
            amount = amountDeposit * (i - startDelay) / vestDuration;
            _assertReleasableIsAmount(amount);
            skip(1);
        }
    }

    function testReleaseAfterCliff() public {
        skip(startDelay + cliffDuration);
        for (uint256 i = startDelay + cliffDuration; i < startDelay + vestDuration; i++) {
            _assertAbilityToRelease(true);
            skip(1);
        }
    }

    function testReleasableAfterVestFullAmount() public {
        vm.warp(startDelay + vestDuration + 1);
        assert(wallet.releasable() == amountDeposit);
        assert(wallet.releasable(address(fakeToken)) == amountDeposit);
    }
}
