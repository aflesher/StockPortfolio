var StockPortfolio = artifacts.require('StockPortfolio'),
  _ = require('lodash');

const toAsciiClean = (hex) => {
  return web3.toAscii(hex).replace(/\u0000/g, '');
}

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
    this.acb = {market: 'tsx', symbol: 'acb', quantity: 800, price: 8.18};
    this.tsla = {market: 'nasdaq', symbol: 'tsla', quantity: 27, price: 291.72};
    this.googl = {market: 'nasdaq', symbol: 'googl', quantity: 9, price: 1077.47};
    this.ttwo = {market: 'nasdaq', symbol: 'ttwo', quantity: 100, price: 110.63};
    this.ry = {market: 'tsx', symbol: 'ry', quantity: 185, price: 96.79};
    this.dis = {market: 'nyse', symbol: 'dis', quantity: 50, price: 103.00};
    this.stocks = [this.acb, this.tsla, this.ttwo, this.ry, this.dis];

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
    let stock = this.stocks[0];
    let profit = Math.round(stock.price * 1.1); // 10%
    let sellPrice = stock.price + profit;

    await this.sp.buy(this.markets[stock.market].index, web3.toHex(stock.symbol), stock.quantity, stock.price * 100);
    await this.sp.sell(this.markets[stock.market].index, web3.toHex(stock.symbol), stock.quantity, sellPrice * 100);

    let expectedProfits = profit * stock.quantity;
    let profits = await this.sp.getProfits(this.markets[stock.market].hex);
    assert.equal(Math.round(profits.toNumber() / 100), expectedProfits, 'profits');

    let sellQuantity = Math.round(stock.quantity / 2); // half

    await this.sp.buy(this.markets[stock.market].index, web3.toHex(stock.symbol), stock.quantity, stock.price * 100);
    await this.sp.sell(this.markets[stock.market].index, web3.toHex(stock.symbol), sellQuantity, sellPrice * 100);

    let nextExpectedProfits = expectedProfits + (profit * sellQuantity);
    let nextProfits = await this.sp.getProfits(this.markets[stock.market].hex);
    assert.equal(Math.round(nextProfits.toNumber() / 100), nextExpectedProfits, 'profits');
  });

  it('should track losses', async () => {
    let stock = this.stocks[0];
    let profit = Math.round(stock.price * 0.9); // 10%
    let sellPrice = stock.price + profit;

    await this.sp.buy(this.markets[stock.market].index, web3.toHex(stock.symbol), stock.quantity, stock.price * 100);
    await this.sp.sell(this.markets[stock.market].index, web3.toHex(stock.symbol), stock.quantity, sellPrice * 100);

    let expectedProfits = profit * stock.quantity;
    let profits = await this.sp.getProfits(this.markets[stock.market].hex);
    assert.equal(Math.round(profits.toNumber() / 100), expectedProfits, 'profits');
  });

  it('should track partial profits', async () => {
    let stock = this.stocks[0];
    let profit = Math.round(stock.price * 1.1); // 10%
    let sellQuantity = Math.round(stock.quantity / 2); // half
    let sellPrice = stock.price + profit;

    await this.sp.buy(this.markets[stock.market].index, web3.toHex(stock.symbol), stock.quantity, stock.price * 100);
    await this.sp.sell(this.markets[stock.market].index, web3.toHex(stock.symbol), sellQuantity, sellPrice * 100);

    let expectedProfits = profit * sellQuantity;
    let profits = await this.sp.getProfits(this.markets[stock.market].hex);
    assert.equal(Math.round(profits.toNumber() / 100), expectedProfits, 'profits');
  });

  it('should accept multi buys', async () => {
    let stocks = this.stocks.slice(0, 3);
    let markets = this.markets;
    let marketIndexes = _.map(stocks, (stock) => {return markets[stock.market].index; });
    let symbols = _.map(stocks, (stock) => {return web3.toHex(stock.symbol);});
    let quantities = _.map(stocks, 'quantity');
    let prices = _.map(stocks, (stock) => { return Math.round(stock.price * 100);});

    await this.sp.bulkBuy(marketIndexes, symbols, quantities, prices);

    for (let index = 0; index < stocks.length; index++) {
      let stock = stocks[index];
      let position = await this.sp.getPosition(stock.key);
      assert.equal(position[0].toNumber(), stock.quantity, 'quantity set');
      assert.equal(position[1].toNumber(), Math.round(stock.price * 100), 'price set');
  
      let trade = await this.sp.getTrade(index);
      assert.equal(toAsciiClean(trade[1]), stock.symbol, 'symbol');
      assert.isFalse(trade[2], 'is not a sell');
      assert.equal(trade[3].toNumber(), stock.quantity, 'quantity');
      assert.equal(trade[4].toNumber(), Math.round(stock.price * 100), 'price');
  
      let holding = await this.sp.getHolding(index);
      assert.equal(holding, stock.key, 'key');
    }
  });
});