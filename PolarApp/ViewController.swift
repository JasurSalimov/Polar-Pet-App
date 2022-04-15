//
//  ViewController.swift
//  PolarApp
//
//  Created by Jasur Salimov on 4/14/22.
//

import UIKit
import PolarBleSdk
import RxSwift
class ViewController: UIViewController{
    private var height: CGFloat = {
        return UIScreen.main.bounds.height
    }()
    private var width: CGFloat = {
        return UIScreen.main.bounds.width
    }()
    private var heartRate: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .black
        label.text = "Heart Rate: "
        label.textAlignment = .left
        return label
    }()
    private var activeCalories: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .black
        label.text = "Calories: "
        label.textAlignment = .left
        return label
    }()
    private var activeTime: UILabel = {
        let label = UILabel()
        label.backgroundColor = .clear
        label.textColor = .black
        label.text = "Time: "
        label.textAlignment = .left
        return label
    }()
    private var tableView: UITableView = {
        let tableView = UITableView()
        tableView.isScrollEnabled = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tableView
    }()
    private var polarDevices:[PolarDevice] = []
    private var api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: Features.hr.rawValue)
    private var bag = DisposeBag()
    private var timer: Timer? = nil
    private var selectedID = String()
    private var hrValue = Int()
    private var time = Int()
    private var calories = Double()
    override func viewDidLoad() {
        super.viewDidLoad()
        properties()
        polarApis()
        // Do any additional setup after loading the view.
    }


}
//MARK: - Property Declaration Methods
extension ViewController{
    private func properties(){
        view.addSubview(heartRate)
        view.addSubview(tableView)
        view.addSubview(activeTime)
        view.addSubview(activeCalories)
        
        heartRate.frame = CGRect(x: (width - 200)/2, y: 150, width: 200, height: 20)
        tableView.frame = CGRect(x: 16, y: 400, width: width - 32, height: 600)
        activeTime.frame = CGRect(x: heartRate.frame.minX, y: heartRate.frame.maxY, width: 200, height: 20)
        activeCalories.frame = CGRect(x: heartRate.frame.minX, y: activeTime.frame.maxY, width: 200, height: 20)
        tableView.delegate = self
        tableView.dataSource = self
        
    }
    private func polarApis(){
        api.searchForDevice()
            .subscribe { [weak self] (deviceId: String, address: UUID, rssi: Int, name: String, connectable: Bool) in
            self?.polarDevices.append(PolarDevice(name: name, id: deviceId, connectable: true))
            self?.tableView.reloadData()
        }onError: { Error in
            print(Error)
        } onCompleted: {
            print("success")
        }.disposed(by: bag)

        api.observer = self
        api.deviceHrObserver = self
        api.powerStateObserver = self
        api.deviceFeaturesObserver = self
    }
}
//MARK: - TableView Related Methods
extension ViewController: UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return polarDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as UITableViewCell
        cell.textLabel?.text = polarDevices[indexPath.item].name
        return cell
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedID = polarDevices[indexPath.item].id
        do {
            try api.connectToDevice(selectedID)
            debugPrint("Trying to connect to - ", selectedID)
        }catch{
            debugPrint(error)
        }
        tableView.reloadData()
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Devices:"
    }
    
}

//MARK: - Polar Api Observer
extension ViewController:PolarBleApiObserver{
    func deviceConnecting(_ identifier: PolarDeviceInfo) {
        debugPrint("Polar Device with -", identifier, "is connecting")
    }
    
    func deviceConnected(_ identifier: PolarDeviceInfo) {
        debugPrint("Polar Device with -", identifier, "is connected")
        let alert = UIAlertController()
        alert.title = identifier.name
        alert.message = "is connected"
        present(alert, animated: true)
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateOnceASecond), userInfo: nil, repeats: true)
        if (identifier.deviceId != selectedID){
            time = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
            alert.dismiss(animated: true)
        })
        let result = api.startAutoConnectToDevice(identifier.rssi, service: nil , polarDeviceType: identifier.deviceId)
        debugPrint("Reconnection established result is: ", result)

        

    }
    
   @objc func updateOnceASecond(){
        time += 1
       if (time%10 == 0){
           calories += 0.014*78*(10/60)*(0.12*Double(hrValue)-7)
       }
       activeTime.text = "Active Time: " + timeFormatted(totalSeconds: time)
       activeCalories.text = "Calories: " + String(Int(calories))
       heartRate.text = "Heart rate is: " + String(hrValue)

    }
    
    func deviceDisconnected(_ identifier: PolarDeviceInfo) {
        debugPrint("Polar Device with -", identifier, "is disconnected")
    }
    func timeFormatted(totalSeconds: Int) -> String {
       let seconds: Int = totalSeconds % 60
       let minutes: Int = (totalSeconds / 60) % 60
       let hours: Int = totalSeconds / 3600
       return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
//MARK: - Polar Power State Observer
extension ViewController:PolarBleApiPowerStateObserver{
    func blePowerOn() {
        debugPrint("Polar is on")
    }
    
    func blePowerOff() {
        
    }
    
    
}
//MARK: - Polar Device Feature Observer
extension ViewController:PolarBleApiDeviceFeaturesObserver{
    func hrFeatureReady(_ identifier: String) {
        
    }
    
    func ftpFeatureReady(_ identifier: String) {
        
    }
    
    func streamingFeaturesReady(_ identifier: String, streamingFeatures: Set<DeviceStreamingFeature>) {

    }
}
//MARK: - Polar Device HR Observer
extension ViewController:PolarBleApiDeviceHrObserver{
    func hrValueReceived(_ identifier: String, data: PolarHrData) {
        hrValue = Int(data.hr)
        debugPrint("Heart rate is received: ", hrValue, Date())
    }
}

struct PolarDevice{
    var name: String
    var id: String
    var connectable: Bool
}
