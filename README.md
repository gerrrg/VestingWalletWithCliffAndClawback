# VestingWalletWithCliffAndClawback

## Overview
An extension of OpenZeppelin's [VestingWallet](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/finance/VestingWallet.sol) contract. This contract adds the following functionality:
* Add a vesting cliff: `beneficiary` cannot claim any vested tokens until a cliff duration has elapsed
* Add `owner`: contract is `Ownable2Step`
* Add clawbacks: contract `owner` can clawback any unvested tokens
* Add post-clawback sweeps: contract `owner` can sweep any excess tokens sent to the contract after clawback
* Add release guard: only `beneficiary` can call `release()` and `release(token)`

## Compilation
`forge build`

## Testing
`forge test`

## Linting
`solhint ./src/*.sol ./test/*.sol`
