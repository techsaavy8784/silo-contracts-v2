// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract BPTTokenLike is ERC20, Ownable {
    constructor() ERC20("Test BPT", "BPT-LIKE") {}
    function mint(address _account, uint256 _amount) external onlyOwner {
        _mint(_account, _amount);
    }
}
