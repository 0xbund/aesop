const Router = artifacts.require('Router');

module.exports = async function(deployer) {
  let admin, smartRouter, wrappedToken, feeRate, feeCollector;

    admin = "TZ8igyyTsRwUxMvhLBoAH8gstReJ97SsXL";
    smartRouter = 'TJ4NNy8xZEqsowCBhLvZ45LCqPdGjkET5j';
    wrappedToken = 'TNUC9Qb1rRpS5CbWLmNMxXBjyFoydXjWFR'; 
    feeRate = '100'; 

  await deployer.deploy(
    Router,
    admin,
    smartRouter,
    wrappedToken,
    feeRate,
  );
};

