// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/OpinionatedVestingWalletFactory.sol";
import "../src/VestingWalletWithCliffAndClawback.sol";

contract OpinionatedVestingWalletFactoryTest is Test {
    OpinionatedVestingWalletFactory public factory;
    VestingWalletWithCliffAndClawback public wallet;

    address owner = vm.addr(0x1);
    address recipient = vm.addr(0x2);

    function setUp() public {
        factory = new OpinionatedVestingWalletFactory();
        address walletAddress = factory.create(owner, recipient, uint64(block.timestamp));
        wallet = VestingWalletWithCliffAndClawback(payable(walletAddress));
    }

    function testWalletIsFromFactory() view public {
        assert(factory.isWalletFromFactory(address(wallet)));
    }

    function testVestDuration() view public {
        assert(wallet.duration() == 4 * 52 weeks);
    }

    function testCliffDuration() view public {
        assert(wallet.cliffDuration() == 52 weeks);
    }
}
