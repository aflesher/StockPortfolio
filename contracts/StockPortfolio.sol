pragma solidity ^0.4.23;

import "./Ownable.sol";

contract StockPortfolio is Ownable {

    struct Trade {
        bytes8 symbol;
        bool isSell;
        uint32 quantity;
        uint32 price;
        uint256 timestamp;
    }

    struct Split {
        bytes8 symbol;
        bool isReverse;
        uint8 spread;
        uint256 timestamp;
    }

    struct Position {
        uint32 quantity;
        uint32 avgPrice;
    }

    Trade[] private trades;
    Split[] private splits;
    mapping (bytes8 => Position) positions;
    bytes8[] private holdings;

    event Bought(bytes8 symbol, uint32 quantity, uint32 price);
    event Sold(bytes8 symbol, uint32 quantity, uint32 price, int64 profits);
    event ForwardSplit(bytes8 symbol, uint8 mulitple);
    event ReverseSplit(bytes8 symbol, uint8 divisor);

    int public profits;

    function () public payable {}

    function buy
    (
        bytes8 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        external
        onlyOwner
    {
        _buy(_symbol, _quantity, _price);
    }

    function bulkBuy
    (
        bytes8[] _symbol,
        uint32[] _quantity,
        uint32[] _price
    )
        external
        onlyOwner
    {
        for (uint i = 0; i < _symbol.length; i++) {
            _buy(_symbol[i], _quantity[i], _price[i]);
        }
    }

    function split
    (
        bytes8 _symbol,
        uint8 _multiple
    )
        external
        onlyOwner
    {
        Position storage position = positions[_symbol];
        require(position.quantity > 0);
        uint32 quantity = (_multiple * position.quantity) - position.quantity;
        _split(_symbol, false, _multiple);
        position.avgPrice = (position.quantity * position.avgPrice) / (position.quantity + quantity);
        position.quantity += quantity;

        emit ForwardSplit(_symbol, _multiple);
    }

    function reverseSplit
    (
        bytes8 _symbol,
        uint8 _divisor,
        uint32 _price
    )
        external
        onlyOwner
    {
        Position storage position = positions[_symbol];
        require(position.quantity > 0);
        uint32 quantity = position.quantity / _divisor;
        uint32 extraQuantity = position.quantity - (quantity * _divisor);
        if (extraQuantity > 0) {
            _sell(_symbol, extraQuantity, _price);
        }
        _split(_symbol, true, _divisor);
        position.avgPrice = position.avgPrice * _divisor;
        position.quantity = quantity;

        emit ReverseSplit(_symbol, _divisor);
    }

    function sell
    (
        bytes8 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        external
        onlyOwner
    {
        _sell(_symbol, _quantity, _price);
    }

    function bulkSell
    (
        bytes8[] _symbol,
        uint32[] _quantity,
        uint32[] _price
    )
        external
        onlyOwner
    {
        for (uint i = 0; i < _symbol.length; i++) {
            _sell(_symbol[i], _quantity[i], _price[i]);
        }
    }

    function getTradesCount() public view returns(uint) {
        return trades.length;
    }

    function getTrade
    (
        uint _index
    )
        public
        view
        returns(
            bytes8 symbol,
            bool isSell,
            uint32 quantity,
            uint32 price,
            uint256 timestamp
        )
    {
        Trade storage trade = trades[_index];
        symbol = trade.symbol;
        isSell = trade.isSell;
        quantity = trade.quantity;
        price = trade.price;
        timestamp = trade.timestamp;
    }

    function getPosition
    (
        bytes8 _symbol
    )
        public
        view
        returns
        (
            uint32 quantity,
            uint32 avgPrice
        )
    {
        Position storage position = positions[_symbol];
        quantity = position.quantity;
        avgPrice = position.avgPrice;
    }

    function getHoldingsCount() public view returns(uint) {
        return holdings.length;
    }

    function getHolding(uint _index) public view returns(bytes8) {
        return holdings[_index];
    }

    function getSplitsCount() public view returns(uint) {
        return splits.length;
    }

    function getSplit
    (
        uint _index
    )
        public
        view
        returns(
            bytes8 symbol,
            bool isReverse,
            uint8 spread,
            uint256 timestamp
        )
    {
        Split storage aSplit = splits[_index];
        symbol = aSplit.symbol;
        isReverse = aSplit.isReverse;
        spread = aSplit.spread;
        timestamp = aSplit.timestamp;
    }

    function _addHolding
    (
        bytes8 _symbol
    )
        private
    {
        holdings.push(_symbol);
    }

    function _removeHolding
    (
        bytes8 _symbol
    )
        private
    {
        if (holdings.length == 0) {
            return;
        }
        bool found = false;
        for (uint i = 0; i < holdings.length; i++) {
            if (found) {
                holdings[i - 1] = holdings[i];
            }

            if (holdings[i] == _symbol) {
                found = true;
            }
        }
        if (found) {
            delete holdings[holdings.length - 1];
            holdings.length--;
        }
    }

    function _trade
    (
        bytes8 _symbol,
        bool _isSell,
        uint32 _quantity,
        uint32 _price
    )
        private
    {
        trades.push(
            Trade({
                symbol: _symbol,
                isSell: _isSell,
                quantity: _quantity,
                price: _price,
                timestamp: now
            })
        );
    }

    function _split
    (
        bytes8 _symbol,
        bool _isReverse,
        uint8 _spread
    )
        private
    {
        splits.push(
            Split({
                symbol: _symbol,
                isReverse: _isReverse,
                spread: _spread,
                timestamp: now
            })
        );
    }

    function _sell
    (
        bytes8 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        private
    {
        Position storage position = positions[_symbol];
        require(position.quantity >= _quantity);
        int64 profit = int64(_quantity * _price) - int64(_quantity * position.avgPrice);
        position.quantity -= _quantity;
        if (position.quantity <= 0) {
            _removeHolding(_symbol);
            delete positions[_symbol];
        }
        profits += profit;
        _trade(_symbol, true, _quantity, _price);
        emit Sold(_symbol, _quantity, _price, profit);
    }

    function _buy
    (
        bytes8 _symbol,
        uint32 _quantity,
        uint32 _price
    )
        private
    {
        _trade(_symbol, false, _quantity, _price);
        Position storage position = positions[_symbol];
        if (position.quantity == 0) {
            _addHolding(_symbol);
        }
        position.avgPrice = ((position.quantity * position.avgPrice) + (_quantity * _price)) /
            (position.quantity + _quantity);
        position.quantity += _quantity;

        emit Bought(_symbol, _quantity, _price);
    }

}