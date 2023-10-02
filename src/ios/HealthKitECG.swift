import HealthKit

@objc(HealthKitECG)
class HealthKitECG : CDVPlugin {
    var commandCallback: String?
    
    @available(iOS 14.0, *)
    @objc(getLatestECG:)
    func getLatestECG(command: CDVInvokedUrlCommand) {
        if HKHealthStore.isHealthDataAvailable(){
            let healthStore = HKHealthStore()
            
            let ecgType = HKObjectType.electrocardiogramType()
            
            let shareTypes = Set<HKSampleType>()
            let readTypes = Set([ecgType])
            let sortType = [NSSortDescriptor.init(key: "startDate", ascending: false)]
            
            healthStore.requestAuthorization(toShare:shareTypes, read: readTypes) { (success, error) in
                if !success {
                    print(error?.localizedDescription as Any)
                    let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Error requesting Health Store authorization:"+(error?.localizedDescription ?? ""))
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                    return
                } else {
                    let ecgQuery = HKSampleQuery(sampleType: ecgType,
                                                 predicate: nil,
                                                 limit: 5,
                                                 sortDescriptors: sortType)
                                                 { (query, samples, error) in
                        if let error = error {
                            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "ECG Query error occurred.")
                            self.commandDelegate.send(result, callbackId: command.callbackId)
                            return
                        }
                        
                        guard let ecgSamples = samples as? [HKElectrocardiogram] else {
                            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Unable to convert ECG Samples to HKElectrocardiograms.")
                            self.commandDelegate.send(result, callbackId: command.callbackId)
                            return
                        }
                        
                        var last5Samples: [[String: Any]] = []
                        let dispatchGroup = DispatchGroup()
                        
                        for sample in ecgSamples.suffix(5) {
                            let startDate = sample.startDate.timeIntervalSince1970
                            let endDate = sample.endDate.timeIntervalSince1970
                            let totalMeasurements = sample.numberOfVoltageMeasurements
                            guard let samplingFrequency = sample.samplingFrequency?.doubleValue(for: HKUnit.hertzUnit(with: HKMetricPrefix.none)) else {
                                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Sampling Frequency not available.")
                                self.commandDelegate.send(result, callbackId: command.callbackId)
                                return
                            }
                            
                            guard let avgHeartRate = sample.averageHeartRate?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) else {
                                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Average Heart Rate not available.")
                                self.commandDelegate.send(result, callbackId: command.callbackId)
                                return
                            }
                                    
                            var voltageMeasurements = Array<Double>()
                            
                            let voltageQuery = HKElectrocardiogramQuery(sample) { (query, result) in
                                switch(result) {
                                    
                                case .measurement(let measurement):
                                    if let voltageQuantity = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                                        voltageMeasurements.append(voltageQuantity.doubleValue(for: HKUnit.voltUnit(with: HKMetricPrefix.micro)))
                                    }
                                    
                                case .done:
                                    last5Samples.insert([
                                        "startDate":startDate,
                                        "endDate":endDate,
                                        "totalMeasurements":totalMeasurements,
                                        "samplingFrequency":samplingFrequency,
                                        "avgHeartRate":avgHeartRate,
                                        "voltages":voltageMeasurements],
                                        at: 0)
                                    return
                                    
                                case .error(let error):
                                    // Handle the error here.
                                    let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error.localizedDescription)
                                    self.commandDelegate.send(result, callbackId: command.callbackId)
                                    return
                                    
                                default:
                                    return
                                    
                                }
                            }
                            
                            healthStore.execute(voltageQuery)
                        }
                        
                        dispatchGroup.notify(queue: .main) {
                            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: last5Samples)
                            self.commandDelegate.send(result, callbackId: command.callbackId)
                            
                        }
                    }
                    
                    // Execute the query.
                    healthStore.execute(ecgQuery)
                }
            }
        } else {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Health Kit Health Store Health Data is not available.")
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
        
    }
}
