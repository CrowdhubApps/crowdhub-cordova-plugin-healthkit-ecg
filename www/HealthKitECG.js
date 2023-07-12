var exec = require("cordova/exec");

exports.getLatestECG = function (success, error) {
  exec(success, error, "HealthKitECG", "getLatestECG");
};
