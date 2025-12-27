//
//  DashboardView.swift
//  SiliconPulse
//
//  Created by Alan on 27/12/25.
//

import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("CPU Load")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(monitor.cpuUsage))%")
                    .font(.title2)
                    .bold()
                    .monospacedDigit() // Keeps text from jumping around
            }
            
            // Chart
            Chart(Array(monitor.history.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("Time", index),
                    y: .value("Usage", value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .blue.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                LineMark(
                    x: .value("Time", index),
                    y: .value("Usage", value)
                )
                .foregroundStyle(.blue)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden) // Clean look
            .frame(height: 80)
            
            Divider()
            
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                Spacer()
            }
        }
        .padding()
        .frame(width: 250, height: 180)
    }
}
