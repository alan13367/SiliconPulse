//
//  SystemMonitor.swift
//  SiliconPulse
//
//  Created by Alan on 27/12/25.
//

import Foundation
import Combine

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var history: [Double] = Array(repeating: 0.0, count: 30) // Last 30 readings
    
    private var timer: Timer?
    private var previousInfo = host_cpu_load_info()
    
    init() {
        // Start the "heartbeat"
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateCPU()
        }
    }
    
    func updateCPU() {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            // Calculate the delta (change) between now and the last check
            let userDiff = Double(info.cpu_ticks.0 - previousInfo.cpu_ticks.0)
            let sysDiff  = Double(info.cpu_ticks.1 - previousInfo.cpu_ticks.1)
            let idleDiff = Double(info.cpu_ticks.2 - previousInfo.cpu_ticks.2)
            let niceDiff = Double(info.cpu_ticks.3 - previousInfo.cpu_ticks.3)
            
            let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
            
            // Avoid division by zero on first run
            if totalTicks > 0 {
                let usage = (totalTicks - idleDiff) / totalTicks
                let percentage = usage * 100.0
                
                DispatchQueue.main.async {
                    self.cpuUsage = percentage
                    self.addToHistory(percentage)
                }
            }
            
            // Save current info for the next comparison
            previousInfo = info
        }
    }
    
    private func addToHistory(_ value: Double) {
        if history.count >= 30 { history.removeFirst() }
        history.append(value)
    }
}
