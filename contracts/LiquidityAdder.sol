// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// Подключаем интерфейс токена
import "./Pair.sol";
import "./interfaces/IERC20.sol";
import "./RouterV2.sol";

interface IBaseV1Factory {
    function allPairsLength() external view returns (uint);
    function isPair(address pair) external view returns (bool);
    function pairCodeHash() external pure returns (bytes32);
    function getPair(address tokenA, address token, bool stable) external view returns (address);
    function createPair(address tokenA, address tokenB, bool stable) external returns (address pair);
}

interface IBaseV1Pair {
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function burn(address to) external returns (uint amount0, uint amount1);
    function mint(address to) external returns (uint liquidity);
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function getAmountOut(uint, address) external view returns (uint);
}

// Контракт пополнения ликвидности пары с помощью одного из токенов
contract LiquidityAdder {
    // Адрес первого токена
    address public tokenA;
    // Адрес второго токена
    address public tokenB;
    // Адрес контракта пары
    address public pair;

    address public buyer;

    // Конструктор контракта
    constructor(address _pair, address _tokenA, address _tokenB) {
        pair = _pair;
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function addLiquidity(address token, uint256 amount) internal returns (uint liquidity) {
        require(token == tokenA || token == tokenB, "Think again and come again");

        (uint reserve0, uint reserve1,) = IBaseV1Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token ? (reserve0, reserve1) : (reserve1, reserve0);
        require(reserveA != 0 && reserveB != 0, "PAIR BALANCE IS NOT ENOUGH");

        uint256 userBalance = IERC20(token).balanceOf(msg.sender);
        require(userBalance >= amount, "Insufficient funds on the user's balance");

        uint256 amountToSell = amount * reserveB / reserveA;

        (t1, t2) = tokenA == token ? (tokenA, tokenB) : (tokenB, tokenA);

        _safeTransferFrom(token, msg.sender, pair, amount);
        _safeTransferFrom(t2, pair, buyer, amountToSell);

        liquidity = IBaseV1Pair(pair).mint(msg.sender);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(erc20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}

