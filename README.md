# Cordova HealthKitECG Plugin

This is a purpose-specific plugin for a client. It only does one thing: checks for ECGs stored in Apple Health on the user's device and returns data for the most recent as a JSON object in the success call.

## Installation

```bash
cordova plugins add https://github.com/ajisakson/HealthKitECG.git
```

Make sure you have the HealthKit entitlement added in Xcode.
Make sure you have the proper NS strings in your Info.plist to request the user's permissions.

## Usage

```javascript
window.HealthKitECG.getLatestECG(
  // first arg should be empty
  "",
  (data) => {
    /**
     * On success, data will be an object with the following properties:
     * - totalMeasurements: The total number of measurements in the ECG
     * - startDate: The start date of the ECG in Unix time
     * - endDate: The end date of the ECG in Unix time
     * - samplingFrequency: The sampling frequency of the ECG in Hz
     * - avgHeartRate: The average heart rate of the ECG in beats per minute
     * - voltages: An array of voltages in the ECG in micro Volts
     */

    // do something with the data
    doSomething(data);
  },
  (err) => {
    alert(
      "An error occurred while attempting to fetch your most recent ECG from Apple Health."
    );
    console.error(err);
  }
);
```

That's it!
