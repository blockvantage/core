// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract DummyContract {
    event Received(address sender, uint256 amount);

    function callTransferFrom(address token, address from, address to, uint256 amount) external returns (bool) {
        return IERC20(token).transferFrom(from, to, amount);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
