var StockPortfolio = artifacts.require("StockPortfolio");

module.exports = function(deployer) {
  // deployment steps
  deployer.deploy(StockPortfolio);
};