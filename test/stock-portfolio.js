var StockPortfolio = artifacts.require('StockPortfolio'),
  _ = require('lodash');

contract('StockPortfolio', async (accounts) => {

  beforeEach('deploy new contract', async () => {
    this.sp = await StockPortfolio.new();
    let marketsCount = await this.sp.getMarketsCount();
    marketsCount = marketsCount.toNumber();
    this.markets = {};
    for (let index = 0; index < marketsCount; index++) {
      let market = await this.sp.getMarket(index);
      this.markets[web3.toAscii(market).replace(/\u0000/g, '')] = { hex: market, index};
    }
    this.stocks = [
      {market: 'tsx', symbol: 'acb', quantity: 800, price: 8.18},
      {market: 'nyse', symbol: 'tsla', quantity: 27, price: 291.72},
      {market: 'nyse', symbol: 'googl', quantity: 9, price: 1077.47},
      {market: 'nyse', symbol: 'ttwo', quantity: 100, price: 110.63},
      {market: 'tsx', symbol: 'ry', quantity: 185, price: 96.79}
    ];

    for (let index = 0; index < this.stocks.length; index++) {
      let stock = this.stocks[index];
      stock.key = await this.sp.getStockKey(web3.toHex(stock.market), web3.toHex(stock.symbol));
    }
  });

  it('should add holdings', async () => {
    let stock = this.stocks[0];
    await this.sp.buy(this.markets[stock.market].index, web3.toHex(stock.symbol), stock.quantity, stock.price * 100);
    let position = await this.sp.getPosition(stock.key);
    assert.equal(position[0].toNumber(), stock.quantity, 'quantity set');
    assert.equal(position[1].toNumber(), stock.price * 100, 'price set');

    let trade = await this.sp.getTrade(0);
    assert.equal(web3.toAscii(trade[0]).replace(/\u0000/g, ''), stock.market, 'market');
    assert.equal(web3.toAscii(trade[1]).replace(/\u0000/g, ''), stock.symbol, 'symbol');
    assert.isFalse(trade[2], 'is not a sell');
    assert.equal(trade[3].toNumber(), stock.quantity, 'quantity');
    assert.equal(trade[4].toNumber(), stock.price * 100, 'price');

    let holding = await this.sp.getHolding(0);
    assert.equal(holding, stock.key, 'stock key');
  });

  it('should track sells', async () => {
    let stock = this.stocks[1];
    let sellPrice = stock.price + 50;

    await this.sp.buy(this.markets[stock.market].index, web3.toHex(stock.symbol), stock.quantity, stock.price * 100);
    await this.sp.sell(this.markets[stock.market].index, web3.toHex(stock.symbol), stock.quantity, sellPrice * 100);

    let position = await this.sp.getPosition(stock.key);
    assert.equal(position[0].toNumber(), 0, 'quantity set');
    assert.equal(position[1].toNumber(), 0, 'price set');

    let trade = await this.sp.getTrade(1);
    assert.equal(web3.toAscii(trade[0]).replace(/\u0000/g, ''), stock.market, 'market');
    assert.equal(web3.toAscii(trade[1]).replace(/\u0000/g, ''), stock.symbol, 'symbol');
    assert.isTrue(trade[2], 'is a sell');
    assert.equal(trade[3].toNumber(), stock.quantity, 'quantity');
    assert.equal(trade[4].toNumber(), sellPrice * 100, 'price');
  });

  it('should track profits', async () => {
    let buy = {
      symbol: 'AAPL',
      quantity: 10,
      price: 187.50
    };

    let sell = {
      symbol: 'AAPL',
      quantity: 10,
      price: 287.50
    }

    await sp.buy(web3.toHex(buy.symbol), buy.quantity, buy.price * 100);
    await sp.sell(web3.toHex(sell.symbol), sell.quantity, sell.price * 100);
    let expectedProfits = (sell.quantity * sell.price) - (buy.quantity * buy.price);
    let profits = await sp.profits.call();
    assert.equal(Math.round(profits.toNumber() / 100), expectedProfits, 'profits');

    let buy2 = {
      symbol: 'NTDOY',
      quantity: 8,
      price: 51.31
    };

    let sell2 = {
      symbol: 'NTDOY',
      quantity: 4,
      price: 24.50
    }

    expectedProfits += ((sell2.quantity * sell2.price) - (sell2.quantity * buy2.price));
    await sp.buy(web3.toHex(buy2.symbol), buy2.quantity, buy2.price * 100);
    await sp.sell(web3.toHex(sell2.symbol), sell2.quantity, sell2.price * 100);
    let profits2 = await sp.profits.call();
    assert.equal(profits2.toNumber() / 100, expectedProfits, 'profits');

    let buy3 = {
      symbol: 'DS.V',
      quantity: 8000,
      price: .20
    };

    let sell3 = {
      symbol: 'DS.V',
      quantity: 8000,
      price: .01
    }

    expectedProfits += ((sell3.quantity * sell3.price) - (sell3.quantity * buy3.price));
    await sp.buy(web3.toHex(buy3.symbol), buy3.quantity, buy3.price * 100);
    await sp.sell(web3.toHex(sell3.symbol), sell3.quantity, sell3.price * 100);
    let profits3 = await sp.profits.call();
    assert.equal(profits3.toNumber() / 100, expectedProfits, 'negative profits');
  });

  it('should accept multi buys', async () => {

    let buys = [
      {symbol: 'ACB.TO', quantity: 800, price: 8.18},
      {symbol: 'TSLA', quantity: 27, price: 291.72},
      {symbol: 'GOOGL', quantity: 9, price: 1077.47},
      {symbol: 'TTWO', quantity: 100, price: 110.63},
      {symbol: 'RY.TO', quantity: 185, price: 96.79}
    ]

    let symbols = _.map(buys, (stock) => {return web3.toHex(stock.symbol);});
    let quantities = _.map(buys, 'quantity');
    let prices = _.map(buys, (stock) => { return Math.round(stock.price * 100);});

    await sp.bulkBuy(symbols, quantities, prices);

    _.each(buys, async (stock, index) => {
      let position = await sp.getPosition(web3.toHex(stock.symbol));
      assert.equal(position[0].toNumber(), stock.quantity, 'quantity set');
      assert.equal(position[1].toNumber(), Math.round(stock.price * 100), 'price set');
  
      let trade = await sp.getTrade(index);
      assert.equal(web3.toAscii(trade[0]).replace(/\u0000/g, ''), stock.symbol, 'symbol');
      assert.isFalse(trade[1], 'is not a sell');
      assert.equal(trade[2].toNumber(), stock.quantity, 'quantity');
      assert.equal(trade[3].toNumber(), Math.round(stock.price * 100), 'price');
  
      let holding = await sp.getHolding(index);
      assert.equal(web3.toAscii(holding).replace(/\u0000/g, ''), stock.symbol, 'symbol');
    });
  });
});