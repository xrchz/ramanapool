#pragma version ^0.3.0

# fulfil deposit
# - take deposit id, ensure the msg.sender owns it and it's pending
# - ensure there is enough rETH to issue: split the deposit amount in proportions
#   10/43, 3/43, 30/43
# - issue rETH
# - issue RamanaETH
# - issue RamanaRPL

# redeem ETH:
# - take RamanaETH
# - enqueue a new redeem ETH id
# - fulfil redeem if possible

# fulfil redeem ETH:
# - take redeem ETH id
# - ensure there is enough ETH to return (1:1 - fee)

# redeem RPL: same as for ETH, using current oDAO RPL price - fee

interface RocketStorage:
  def getAddress(_key: bytes32) -> address: view

interface RocketPrices:
  def getRPLPrice() -> uint256: view

rocketTokenRPLKey: constant(bytes32) = keccak256("contract.addressrocketTokenRPL")
rocketTokenRETHKey: constant(bytes32) = keccak256("contract.addressrocketTokenRETH")
rocketPricesKey: constant(bytes32) = keccak256("contract.addressrocketNetworkPrices")

rETHSplit: public(uint256)
RPLSplit: public(uint256)
splitDenominator: public(uint256)

interface ERC20:
 def transfer(_to: address, _value: uint256) -> bool: nonpayable

 def setPool(_pool: address): nonpayable
 def mint(_value: uint256): nonpayable
 def burn(_value: uint256): nonpayable

 def getRethValue(_ethValue: uint256): view

ramana: public(address)
pendingRamana: public(address)
feeDenominator: public(constant(uint256)) = 1000000
feeNumerator: public(uint256)

RamanaETH: public(immutable(ERC20))
RamanaRPL: public(immutable(ERC20))
rocketStorage: public(immutable(RocketStorage))
rETH: public(immutable(ERC20))
RPL: public(immutable(ERC20))

struct Item:
  owner: address
  value: uint256

deposits: public(HashMap[uint256, Item])
redemptionsETH: public(HashMap[uint256, Item])
redemptionsRPL: public(HashMap[uint256, Item])

nextDeposit: public(uint256)
nextRedeemETH: public(uint256)
nextRedeemRPL: public(uint256)

event FeeChange:
  oldFee: indexed(uint256)
  newFee: indexed(uint256)

event SplitChange:
  rETH: indexed(uint256)
  RPL: indexed(uint256)
  denominator: indexed(uint256)

@external
def setRamana(_newRamana: address):
  assert msg.sender == self.ramana, "auth"
  self.pendingRamana = _newRamana

@external
def confirmRamana():
  assert msg.sender == self.pendingRamana, "auth"
  self.ramana = self.pendingRamana

@external
def setFee(n: uint256):
  assert msg.sender == self.ramana, "auth"
  assert n <= feeDenominator, "bound"
  log FeeChange(self.feeNumerator, n)
  self.feeNumerator = n

@external
def setSplits(_reth: uint256, _rpl: uint256, _den: uint256):
  assert msg.sender == self.ramana, "auth"
  assert _reth + _rpl <= _den, "sum"
  self.splitDenominator = _den
  self.rETHSplit = _reth
  self.RPLSplit = _rpl
  log SplitChange(_reth, _rpl, _den)

@external
def transfer(_token: ERC20, _to: address, _value: uint256):
  assert msg.sender == self.ramana, "auth"
  if _token.address == empty(address):
    send(_to, _value)
  else:
    assert _token.transfer(_to, _value), "transfer"

@external
@payable
def deposit():
  self._deposit()

@external
@payable
def __default__():
  self._deposit()

@internal
@payable
def _deposit():
  deposit: Item = Item({owner: msg.sender, value: msg.value})
  self.deposits[self.nextDeposit] = deposit
  self._fulfilDeposit(self.nextDeposit)
  self.nextDeposit += 1

@internal
@payable
def _fulfilDeposit(_id: uint256):
  deposit: Item = self.deposits[_id]
  assert msg.sender == deposit.owner, "auth"
  ethForRETH: uint256 = msg.value * self.rETHSplit / self.splitDenominator
  ethForRPL: uint256 = msg.value * self.RPLSplit / self.splitDenominator
  ethForETH: uint256 = msg.value - ethForRETH - ethForRPL
  rocketPrices: RocketPrices = RocketPrices(rocketStorage.getAddress(rocketPricesKey))
  RamanaETH.mint(ethForETH)
  # TODO: fill this out
  self.deposits[_id] = empty(Item)

@external
def __init__(_rocketStorage: address, _addressETH: address, _addressRPL: address):
  self.ramana = msg.sender
  RamanaETH = ERC20(_addressETH)
  RamanaRPL = ERC20(_addressRPL)
  RamanaETH.setPool(self)
  RamanaRPL.setPool(self)
  rocketStorage = RocketStorage(_rocketStorage)
  rETH = ERC20(rocketStorage.getAddress(rocketTokenRETHKey))
  RPL = ERC20(rocketStorage.getAddress(rocketTokenRPLKey))
  self.splitDenominator = 43
  self.rETHSplit = 30
  self.RPLSplit = 3
