// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "hardhat/console.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";

contract TriangularFlashSwap {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 private deadline = block.timestamp + 1 days;
    uint256 private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    function fundContract(
        address _owner,
        address _token,
        uint256 _amount
    ) public {
        IERC20(_token).transferFrom(_owner, _token, _amount);
    }

    function getTokenBalance(address _address) public view returns (uint256) {
        return IERC20(_address).balanceOf(address(this));
    }

    function startArbitrage(
        address _tokenBorrow,
        uint256 _amount,
        address _token0,
        address _token1,
        address _factory,
        address _router,
        address _dummyToken
    ) external {
        require(
            _tokenBorrow != address(0),
            "Borrowing token address must be valid."
        );
        require(_amount > 0, "Borrowing amount must be larger than zero");
        require(_token0 != address(0), "Token0 address must be valid.");
        require(_token1 != address(0), "Token1 address must be valid.");
        require(_factory != address(0), "Factory address must be valid.");
        require(_router != address(0), "Router address must be valid.");

        IERC20(_tokenBorrow).safeApprove(address(_router), MAX_INT);
        IERC20(_token0).safeApprove(address(_router), MAX_INT);
        IERC20(_token1).safeApprove(address(_router), MAX_INT);

        address pair = IUniswapV2Factory(_factory).getPair(
            _tokenBorrow,
            _dummyToken
        );

        require(pair != address(0), "Pool for selected pair does not exist");

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        uint256 amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint256 amount1Out = _tokenBorrow == token1 ? _amount : 0;

        bytes memory data = abi.encode(
            _tokenBorrow,
            _amount,
            msg.sender,
            _token0,
            _token1,
            _factory,
            _router
        );

        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    function pancakeCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        bytes memory data = _data;
        executeArbitrage(_sender, _amount0, _amount1, data);
    }

    function uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        bytes memory data = _data;
        executeArbitrage(_sender, _amount0, _amount1, data);
    }

    function executeArbitrage(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) private {
        (
            address tokenBorrow,
            uint256 amount,
            address senderAddress,
            address token0,
            address token1,
            address factory,
            address router
        ) = abi.decode(
                _data,
                (address, uint256, address, address, address, address, address)
            );

        address pair = getPair(msg.sender, factory);

        require(msg.sender == pair, "Pair contract didn't execute arbitrage.");
        require(
            _sender == address(this),
            "Initiater didn't match this contract."
        );

        uint256 repayAmount = getLoanAmount(amount);

        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;

        uint256 receivedAmount = executeTriangularTrades(
            tokenBorrow,
            token0,
            token1,
            loanAmount,
            factory,
            router
        );

        require(
            checkProfitability(repayAmount, receivedAmount),
            "Arbitrage not profitable. Transaction reverted."
        );

        payOut(
            tokenBorrow,
            senderAddress,
            SafeMath.sub(receivedAmount, repayAmount)
        );

        payBackLoan(tokenBorrow, pair, repayAmount);
    }

    function executeTriangularTrades(
        address _tokenBorrow,
        address _token0,
        address _token1,
        uint256 _loanAmount,
        address _factory,
        address _router
    ) private returns (uint256) {
        uint256 trade1AcquiredCoin = placeTrade(
            _tokenBorrow,
            _token0,
            _loanAmount,
            _factory,
            _router
        );
        uint256 trade2AcquiredCoin = placeTrade(
            _token0,
            _token1,
            trade1AcquiredCoin,
            _factory,
            _router
        );
        uint256 trade3AcquiredCoin = placeTrade(
            _token1,
            _tokenBorrow,
            trade2AcquiredCoin,
            _factory,
            _router
        );

        return trade3AcquiredCoin;
    }

    function placeTrade(
        address _fromToken,
        address _toToken,
        uint256 _amountIn,
        address _factory,
        address _router
    ) private returns (uint256) {
        address pair = IUniswapV2Factory(_factory).getPair(
            _fromToken,
            _toToken
        );

        require(pair != address(0), "Pool for pair does not exist");

        // Calculate amount out
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;

        uint256 amountRecquired = IUniswapV2Router01(_router).getAmountsOut(
            _amountIn,
            path
        )[1];

        uint256 amountReceived = IUniswapV2Router01(_router)
            .swapExactTokensForTokens(
                _amountIn,
                amountRecquired,
                path,
                address(this),
                deadline
            )[1];

        require(amountReceived > 0, "Aborted TX: Trade returned zero");
        return amountReceived;
    }

    function getPair(address _sender, address _factory)
        private
        view
        returns (address)
    {
        address token0Pair = IUniswapV2Pair(_sender).token0();
        address token1Pair = IUniswapV2Pair(_sender).token1();
        return IUniswapV2Factory(_factory).getPair(token0Pair, token1Pair);
    }

    function getLoanAmount(uint256 _amount) private pure returns (uint256) {
        return
            SafeMath.add(
                _amount,
                SafeMath.add(SafeMath.div(SafeMath.mul(_amount, 3), 977), 1)
            );
    }

    function payOut(
        address _tokenBorrow,
        address _senderAddress,
        uint256 _amount
    ) private {
        IERC20 payoutToken = IERC20(_tokenBorrow);
        payoutToken.transfer(_senderAddress, _amount);
    }

    function payBackLoan(
        address _tokenBorrow,
        address _pair,
        uint256 _repayAmount
    ) private {
        IERC20(_tokenBorrow).transfer(_pair, _repayAmount);
    }

    function checkProfitability(uint256 _input, uint256 _output)
        private
        pure
        returns (bool)
    {
        return _output > _input;
    }
}
