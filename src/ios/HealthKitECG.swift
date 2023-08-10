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
            
            healthStore.requestAuthorization(toShare:shareTypes, read: readTypes) { (success, error) in
                if !success {
                    print(error?.localizedDescription as Any)
                } else {
                    
                    let ecgQuery = HKSampleQuery(sampleType: ecgType,
                                                 predicate: nil,
                                                 limit: HKObjectQueryNoLimit,
                                                 sortDescriptors: nil) { (query, samples, error) in
                        if let error = error {
                            // Handle the error here.
                            fatalError("*** An error occurred \(error.localizedDescription) ***")
                        }
                        
                        guard let ecgSamples = samples as? [HKElectrocardiogram] else {
                            fatalError("*** Unable to convert \(String(describing: samples)) to [HKElectrocardiogram] ***")
                        }
                        
                        var last5Samples: [[String: Any]] = []
                        let dispatchGroup = DispatchGroup()
                        
                        for sample in ecgSamples.suffix(5) {
                            let startDate = sample.startDate.timeIntervalSince1970
                            let endDate = sample.endDate.timeIntervalSince1970
                            let totalMeasurements = sample.numberOfVoltageMeasurements
                            let samplingFrequency = sample.samplingFrequency?.doubleValue(for: HKUnit.hertzUnit(with: HKMetricPrefix.none))
                            let avgHeartRate = sample.averageHeartRate?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                            var voltageMeasurements = Array<Double>()
                            
                            let voltageQuery = HKElectrocardiogramQuery(sample) { (query, result) in
                                switch(result) {
                                    
                                case .measurement(let measurement):
                                    if let voltageQuantity = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                                        voltageMeasurements.append(voltageQuantity.doubleValue(for: HKUnit.voltUnit(with: HKMetricPrefix.micro)))
                                    }
                                    
                                case .done:
                                    // No more voltage measurements. Finish processing the existing measurements.
                                    last5Samples.insert(["startDate":startDate, "endDate":endDate, "totalMeasurements":totalMeasurements, "samplingFrequency":samplingFrequency, "avgHeartRate":avgHeartRate, "voltages":voltageMeasurements], at: 0)
                                    dispatchGroup.leave()
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
                            
                            dispatchGroup.enter()
                            healthStore.execute(voltageQuery)
                        }
                        
                        dispatchGroup.notify(queue: .main) {
                            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: last5Samples)
                            self.commandDelegate.send(result, callbackId: command.callbackId)
                            
                        }
                    }
                    
                    
                    print("Executing ECG Query")
                    
                    // Execute the query.
                    healthStore.execute(ecgQuery)
                }
            }
        } else {
            print("nope!")
        }
        
    }
}
