#pragma version ^0.3.0

event Transfer:
  _from: indexed(address)
  _to: indexed(address)
  _value: uint256

event Approval:
  _owner: indexed(address)
  _spender: indexed(address)
  _value: uint256

@external
@view
def name() -> String[10]:
  return "Ramana RPL"

@external
@view
def symbol() -> String[10]:
  return "RamanaRPL"

@external
@view
def decimals() -> uint8:
  return 18

totalSupply: public(uint256)

balanceOf: public(HashMap[address, uint256])

allowance: public(HashMap[address, HashMap[address, uint256]])

@internal
def _transfer(_from: address, _to: address, _value: uint256):
  assert _value <= self.balanceOf[_from], "insufficient balance"
  self.balanceOf[_from] = unsafe_sub(self.balanceOf[_from], _value)
  self.balanceOf[_to] = self.balanceOf[_to] + _value
  log Transfer(_from, _to, _value)

@external
def transfer(_to: address, _value: uint256) -> bool:
  self._transfer(msg.sender, _to, _value)
  return True

@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
  assert _value <= self.allowance[msg.sender][_from], "insufficient allowance"
  self.allowance[msg.sender][_from] = unsafe_sub(self.allowance[msg.sender][_from], _value)
  self._transfer(_from, _to, _value)
  return True

@external
def approve(_spender: address, _value: uint256) -> bool:
  self.allowance[msg.sender][_spender] = _value
  log Approval(msg.sender, _spender, _value)
  return True

@external
def __init__():
  pass
