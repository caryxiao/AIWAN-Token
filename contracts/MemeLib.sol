// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// WETH9接口
interface IWETH {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

library MemeLib {
    /**
     * @dev 将ETH转换为WETH
     * @param _amount 要转换的ETH数量
     * @param _wethAddress WETH9合约地址
     */
    function wrapETH(uint256 _amount, address _wethAddress) internal {
        if (_amount > 0) {
            IWETH(_wethAddress).deposit{value: _amount}();
        }
    }

    /**
     * @dev 将WETH转换为ETH
     * @param _amount 要转换的WETH数量
     * @param _wethAddress WETH9合约地址
     */
    function unwrapWETH(uint256 _amount, address _wethAddress) internal {
        if (_amount > 0) {
            IWETH(_wethAddress).withdraw(_amount);
        }
    }
}
