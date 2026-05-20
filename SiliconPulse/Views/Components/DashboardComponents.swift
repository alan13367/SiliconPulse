import SwiftUI
import Charts

struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

struct SparklineChart: View {
    let data: [Double]
    let color: Color
    var yDomain: ClosedRange<Double>? = nil

    var body: some View {
        if data.count > 1 {
            Chart(Array(data.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("Time", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(
                    LinearGradient(colors: [color.opacity(0.2), color.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
            }
            .applyIf(yDomain != nil) { chart in
                chart.chartYScale(domain: yDomain!)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(maxWidth: .infinity, minHeight: 36, idealHeight: 36)
            .clipped()
        }
    }
}

struct MetricValue: View {
    let value: Double
    let unit: String

    var body: some View {
        Text("\(Int(value))\(unit)")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .monospacedDigit()
    }
}

struct TemperatureBadge: View {
    let temperature: Double
    let useFahrenheit: Bool

    private var color: Color {
        switch temperature {
        case ..<40: return .green
        case 40..<55: return .yellow
        case 55..<70: return .orange
        case 70..<85: return .red
        default: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "thermometer")
                .font(.caption2)
            Text(Formatters.temperature(temperature, useFahrenheit: useFahrenheit))
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

extension View {
    @ViewBuilder
    func applyIf<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
