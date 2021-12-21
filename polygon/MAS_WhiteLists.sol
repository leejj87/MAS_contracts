// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
contract registryAddress is Ownable{
    mapping (address=>bool) registeredMasMusicians;
    constructor () {
        registeredMasMusicians[msg.sender]=true;
    }
    function register(address _userAddress) public onlyOwner{
        registeredMasMusicians[_userAddress]=true;
    }
    function unregister(address _userAddress) public onlyOwner{
        registeredMasMusicians[_userAddress]=false;
    }
    function isRegistered(address _userAddress) public view returns(bool){
        return registeredMasMusicians[_userAddress];
    }
}
