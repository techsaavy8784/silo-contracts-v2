methods {
    // Getters: 
    function config() external returns(address) envfree;
    function factory() external returns(address) envfree;
    function getProtectedAssets() external returns(uint256) envfree;
    function getCollateralAssets() external returns(uint256) envfree;
    function getDebtAssets() external returns(uint256) envfree;
    // Harness:
    function getSiloDataInterestRateTimestamp() external returns(uint256) envfree;
}
