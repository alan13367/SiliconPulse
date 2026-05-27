import SwiftUI

struct OnboardingView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            VStack(spacing: 12) {
                OnboardingOptionRow(
                    icon: "power.circle.fill",
                    tint: .accentColor,
                    title: "Start with macOS",
                    subtitle: "Keep SiliconPulse ready in the menu bar after you sign in."
                ) {
                    Toggle("", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    ))
                    .labelsHidden()
                }

                OnboardingOptionRow(
                    icon: "thermometer.medium",
                    tint: .orange,
                    title: "Temperature units",
                    subtitle: "Choose how thermal readings appear in the dashboard."
                ) {
                    Picker("", selection: Binding(
                        get: { settings.useFahrenheit },
                        set: {
                            settings.useFahrenheit = $0
                            settings.save()
                        }
                    )) {
                        Text("C").tag(false)
                        Text("F").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 88)
                }

                OnboardingOptionRow(
                    icon: "speedometer",
                    tint: .cyan,
                    title: "Refresh pace",
                    subtitle: "Pick how often CPU and process metrics update."
                ) {
                    Picker("", selection: Binding(
                        get: { settings.updateInterval },
                        set: {
                            settings.updateInterval = $0
                            settings.save()
                            SystemMonitor.shared.startMonitoring(interval: $0)
                            ProcessMonitor.shared.startMonitoring(interval: $0)
                        }
                    )) {
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                        Text("5s").tag(5.0)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 132)
                }
            }

            if let error = settings.launchAtLoginError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Button("Open Settings") {
                    settings.completeOnboarding()
                    dismiss()
                    openSettings()
                    AppWindows.presentSettings()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Start Monitoring") {
                    settings.completeOnboarding()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(minWidth: 500, minHeight: 390)
        .nativePanelBackground()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "waveform.path.ecg.rectangle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.cyan)
                .padding(12)
                .background(.cyan.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.cyan.opacity(0.28), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to SiliconPulse")
                    .font(.title2.weight(.semibold))
                Text("Set the essentials once, then keep an eye on your Mac from the menu bar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingOptionRow<Accessory: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)
            accessory
        }
        .padding(14)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        }
    }
}
