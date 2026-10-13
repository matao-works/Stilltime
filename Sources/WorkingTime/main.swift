import SwiftUI
import AppKit
import Combine

@main
struct WorkingTimeApp: App {
    @StateObject private var session = WorkSession()
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle

    var body: some Scene {
        WindowGroup(id: "dashboard") {
            DashboardView()
                .onAppear { lifecycle.session = session }
                .environmentObject(session)
                .frame(minWidth: 760, minHeight: 620)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .commands { CommandGroup(replacing: .newItem) {} }

        MenuBarExtra {
            MenuBarPanel().environmentObject(session)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: session.isActive ? "bolt.fill" : "moon.zzz.fill")
                if session.isActive { Text(session.shortRemaining) }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppLifecycle: NSObject, NSApplicationDelegate {
    weak var session: WorkSession?
    func applicationWillTerminate(_ notification: Notification) { session?.stop() }
}

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let plannedMinutes: Int
    let actualSeconds: Int
    let completed: Bool
}

@MainActor
final class WorkSession: ObservableObject {
    @Published var isActive = false
    @Published var secondsLeft = 0
    @Published var selectedMinutes = 60
    @Published var customHours = 2
    @Published var customMinutes = 0
    @Published var errorMessage: String?
    @Published private(set) var keepsDisplayAwake = true
    private var process: Process?
    private var displayProcess: Process?
    private var timer: Timer?
    private var startedAt: Date?
    private var startedUptime: TimeInterval?
    private var sessionMinutes = 0
    @Published private(set) var history: [SessionRecord] = []
    @Published private(set) var totalWorkSeconds = 0
    @Published private(set) var totalSessionCount = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: "sessionHistory"),
           let records = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            history = records
        }
        totalWorkSeconds = UserDefaults.standard.object(forKey: "totalWorkSeconds") as? Int ?? history.reduce(0) { $0 + $1.actualSeconds }
        totalSessionCount = UserDefaults.standard.object(forKey: "totalSessionCount") as? Int ?? history.count
    }

    let presets: [(String, Int, String)] = [
        ("25 分钟", 25, "到时自动结束"), ("1 小时", 60, "到时自动结束"),
        ("2 小时", 120, "到时自动结束"), ("4 小时", 240, "到时自动结束")
    ]

    var progress: Double {
        guard startedUptime != nil, isActive else { return 0 }
        let total = Double(max(1, sessionMinutes * 60))
        return min(1, max(0, 1 - Double(secondsLeft) / total))
    }
    var remaining: String {
        let h = secondsLeft / 3600, m = (secondsLeft % 3600) / 60, s = secondsLeft % 60
        return h > 0 ? String(format: "%02d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
    var shortRemaining: String { secondsLeft >= 3600 ? "\(secondsLeft / 3600)h" : "\(max(1, secondsLeft / 60))m" }

    func start(minutes: Int? = nil) {
        guard !isActive else { return }
        let duration = max(1, minutes ?? selectedMinutes)
        selectedMinutes = duration
        let seconds = duration * 60
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = ["-i", "-t", String(seconds)]
        task.terminationHandler = { [weak self, weak task] _ in
            DispatchQueue.main.async {
                guard let self, let task, self.process === task else { return }
                self.finish(completed: task.terminationStatus == 0)
            }
        }
        do {
            try task.run()
            process = task
            startedAt = Date()
            startedUptime = ProcessInfo.processInfo.systemUptime
            sessionMinutes = duration
            secondsLeft = seconds
            isActive = true
            errorMessage = nil
            if keepsDisplayAwake { enableDisplayAssertion() }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.tick() }
            }
            if let timer { RunLoop.main.add(timer, forMode: .common) }
        } catch {
            errorMessage = "无法开启防睡眠：\(error.localizedDescription)"
        }
    }

    private func tick() {
        guard isActive, let startedUptime else { return }
        let elapsed = max(0, ProcessInfo.processInfo.systemUptime - startedUptime)
        secondsLeft = max(0, Int(ceil(Double(sessionMinutes * 60) - elapsed)))
        if secondsLeft == 0 {
            if let process, process.isRunning { process.terminate() }
            process = nil
            finish(completed: true)
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        if let process, process.isRunning { process.terminate() }
        self.process = nil
        finish()
    }

    func toggleDisplayAwake() {
        if keepsDisplayAwake {
            displayProcess?.terminate()
            displayProcess = nil
            keepsDisplayAwake = false
        } else if !isActive {
            keepsDisplayAwake = true
        } else if enableDisplayAssertion() {
            keepsDisplayAwake = true
        }
    }

    @discardableResult
    private func enableDisplayAssertion() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = ["-d", "-t", String(max(1, secondsLeft))]
        do {
            try task.run()
            displayProcess = task
            return true
        } catch {
            errorMessage = "无法保持屏幕点亮：\(error.localizedDescription)"
            keepsDisplayAwake = false
            return false
        }
    }

    private func finish(completed: Bool = false) {
        if isActive, let startedAt, let startedUptime {
            let elapsed = max(0, ProcessInfo.processInfo.systemUptime - startedUptime)
            let record = SessionRecord(id: UUID(), startedAt: startedAt, endedAt: Date(),
                                       plannedMinutes: sessionMinutes,
                                       actualSeconds: min(sessionMinutes * 60, Int(elapsed)), completed: completed)
            totalWorkSeconds += record.actualSeconds
            totalSessionCount += 1
            UserDefaults.standard.set(totalWorkSeconds, forKey: "totalWorkSeconds")
            UserDefaults.standard.set(totalSessionCount, forKey: "totalSessionCount")
            history.insert(record, at: 0)
            history = Array(history.prefix(1000))
            if let data = try? JSONEncoder().encode(history) {
                UserDefaults.standard.set(data, forKey: "sessionHistory")
            }
        }
        if let displayProcess, displayProcess.isRunning { displayProcess.terminate() }
        displayProcess = nil
        timer?.invalidate(); timer = nil
        process = nil; startedAt = nil; startedUptime = nil
        isActive = false; secondsLeft = 0
    }
}

struct DashboardView: View {
    @EnvironmentObject private var session: WorkSession
    @State private var tab = 0
    @State private var showsHistory = false
    private let ink = Color(red: 0.055, green: 0.075, blue: 0.12)
    private let mint = Color(red: 0.42, green: 0.94, blue: 0.72)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.075, green: 0.105, blue: 0.16), ink], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                HStack(spacing: 0) {
                    sidebar.frame(width: 210)
                    Rectangle().fill(.white.opacity(0.07)).frame(width: 1)
                    if showsHistory { historyPanel } else { mainPanel }
                }
            }
        }
        .alert("提示", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })) {
            Button("知道了", role: .cancel) { session.errorMessage = nil }
        } message: { Text(session.errorMessage ?? "") }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(mint.opacity(0.14)).frame(width: 38, height: 38)
                Image(systemName: "hourglass") .font(.system(size: 17, weight: .semibold)).foregroundStyle(mint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("STILLTIME").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(2.2).foregroundStyle(.white)
                Text("定时防睡眠").font(.system(size: 9, weight: .medium)).tracking(1.35).foregroundStyle(.white.opacity(0.38))
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(session.isActive ? mint : Color.white.opacity(0.25)).frame(width: 7, height: 7)
                Text(session.isActive ? "防睡眠已开启" : "防睡眠未开启").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.68))
            }.padding(.horizontal, 12).padding(.vertical, 8).background(.white.opacity(0.055), in: Capsule())
        }
        .padding(.horizontal, 26).padding(.vertical, 19)
        .background(.black.opacity(0.12))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 25) {
            VStack(alignment: .leading, spacing: 8) {
                Text("功能").font(.system(size: 10, weight: .semibold)).tracking(1.3).foregroundStyle(.white.opacity(0.34)).padding(.leading, 10)
                Button { showsHistory = false } label: {
                    sideItem("timer", "定时防睡眠", selected: !showsHistory)
                }.buttonStyle(.plain)
                Button { showsHistory = true } label: {
                    sideItem("chart.bar.xaxis", "使用记录", selected: showsHistory)
                }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("快捷选择").font(.system(size: 10, weight: .semibold)).tracking(1.3).foregroundStyle(.white.opacity(0.34)).padding(.leading, 10)
                ForEach(session.presets, id: \.1) { item in
                    Button { session.selectedMinutes = item.1; showsHistory = false; tab = 0 } label: {
                        HStack { Text(item.0); Spacer(); Image(systemName: session.selectedMinutes == item.1 ? "checkmark" : "clock").font(.system(size: 9, weight: .semibold)).opacity(0.38) }
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(session.selectedMinutes == item.1 ? mint : .white.opacity(0.62))
                            .padding(.horizontal, 10).padding(.vertical, 11).frame(maxWidth: .infinity).contentShape(Rectangle()).background(session.selectedMinutes == item.1 ? mint.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).disabled(session.isActive)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "lock.shield").foregroundStyle(mint.opacity(0.75))
                Text("本地运行 · 无需联网").foregroundStyle(.white.opacity(0.38))
            }.font(.system(size: 10)).padding(.leading, 8).padding(.bottom, 4)
        }.padding(20).frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func sideItem(_ icon: String, _ title: String, selected: Bool) -> some View {
        HStack(spacing: 10) { Image(systemName: icon).frame(width: 16); Text(title); Spacer() }
            .font(.system(size: 12, weight: selected ? .semibold : .regular)).foregroundStyle(selected ? .white : .white.opacity(0.45))
            .padding(.horizontal, 10).padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(selected ? .white.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Text("使用记录").font(.system(size: 25, weight: .semibold, design: .rounded))
                Text("查看防睡眠使用时长，记录仅保存在这台 Mac。").font(.system(size: 12)).foregroundStyle(.white.opacity(0.47))
            }
            HStack(spacing: 12) {
                historyMetric("累计防睡眠", value: elapsedLabel(session.totalWorkSeconds))
                historyMetric("使用次数", value: "\(session.totalSessionCount) 次")
                historyMetric("今日防睡眠", value: elapsedLabel(session.history.filter { Calendar.current.isDateInToday($0.startedAt) }.reduce(0) { $0 + $1.actualSeconds }))
            }
            HStack {
                Text("历史记录").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("最近 1,000 条").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if session.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 32)).foregroundStyle(mint.opacity(0.7))
                    Text("还没有使用记录").font(.system(size: 14, weight: .medium))
                    Text("防睡眠到时结束或手动关闭后，会自动保存记录。").font(.system(size: 11)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(session.history) { record in
                            HStack(spacing: 12) {
                                Image(systemName: record.completed ? "checkmark.circle.fill" : "stop.circle")
                                    .foregroundStyle(record.completed ? mint : .white.opacity(0.4))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12, weight: .medium))
                                    Text("设定 \(durationLabel(record.plannedMinutes)) · \(record.completed ? "到时结束" : "手动关闭")")
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(elapsedLabel(record.actualSeconds)).font(.system(size: 13, weight: .medium, design: .rounded)).monospacedDigit()
                            }.padding(14).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 11))
                        }
                    }
                }
            }
            if session.isActive {
                HStack {
                    Label("防睡眠已开启 · 剩余 \(session.remaining)", systemImage: "bolt.fill").foregroundStyle(mint)
                    Spacer()
                    Button("关闭防睡眠") { session.stop() }.buttonStyle(.bordered)
                }.font(.system(size: 12)).padding(12).background(mint.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func historyMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 19, weight: .medium, design: .rounded)).foregroundStyle(.white)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }

    private func elapsedLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) 秒" }
        if seconds < 3600 { return "\(seconds / 60) 分 \(seconds % 60) 秒" }
        return "\(seconds / 3600) 小时 \((seconds % 3600) / 60) 分"
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("定时防睡眠").font(.system(size: 25, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    Text("让电脑在指定时间内不自动睡眠，长任务持续运行。").font(.system(size: 12)).foregroundStyle(.white.opacity(0.47))
                }
                Spacer()

            }.padding(.top, 30)

            HStack(spacing: 12) {
                Button { session.toggleDisplayAwake() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: session.keepsDisplayAwake ? "sun.max.fill" : "moon.fill")
                        Text(session.keepsDisplayAwake ? "保持屏幕点亮" : "允许屏幕自动熄灭")
                        Image(systemName: "switch.2")
                            .foregroundStyle(session.keepsDisplayAwake ? mint : .white.opacity(0.4))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(session.keepsDisplayAwake ? mint.opacity(0.08) : .white.opacity(0.04), in: Capsule())
                    .contentShape(Capsule())
                }.buttonStyle(.plain)
                .help("防睡眠开启期间，允许屏幕熄灭也不会让电脑自动睡眠。")
                Rectangle().fill(.white.opacity(0.16)).frame(width: 1, height: 12)
                Label(session.isActive ? "电脑不会自动睡眠" : "开始后阻止自动睡眠", systemImage: "moon.zzz.fill")
            }.font(.system(size: 10, weight: .medium)).foregroundStyle(mint.opacity(0.83)).padding(.top, 16)

            Spacer(minLength: 18)
            timerCard
            Spacer(minLength: 20)

            HStack {
                Text("多久后结束防睡眠").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                HStack(spacing: 2) {
                    tabButton("常用时长", index: 0); tabButton("自定义", index: 1)
                }.padding(3).background(.black.opacity(0.25), in: Capsule())
            }
            if tab == 0 { presetGrid.padding(.top, 14) } else { customPicker.padding(.top, 14) }
            HStack(spacing: 10) {
                Button { if session.isActive { session.stop() } else { session.start(minutes: tab == 0 ? session.selectedMinutes : customDuration) } } label: {
                    HStack(spacing: 9) {
                        Image(systemName: session.isActive ? "stop.fill" : "bolt.fill")
                        Text(session.isActive ? "关闭防睡眠" : "开始防睡眠")
                    }.font(.system(size: 13, weight: .semibold)).foregroundStyle(ink).frame(maxWidth: .infinity).padding(.vertical, 13).background(mint, in: RoundedRectangle(cornerRadius: 11))
                }.buttonStyle(.plain)
                if !session.isActive {
                    Button { NSApplication.shared.terminate(nil) } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.65)).frame(width: 46, height: 43).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain).help("退出 Stilltime")
                }
            }.padding(.top, 18).padding(.bottom, 24)
        }.padding(.horizontal, 30).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var timerCard: some View {
        HStack(spacing: 24) {
            ZStack {
                Circle().stroke(.white.opacity(0.07), lineWidth: 7)
                Circle().trim(from: 0, to: session.isActive ? session.progress : 0.72).stroke(AngularGradient(colors: [mint.opacity(0.28), mint], center: .center), style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Image(systemName: session.isActive ? "bolt.fill" : "hourglass").font(.system(size: 16, weight: .medium)).foregroundStyle(mint)
                    Text(session.isActive ? "已开启" : "未开启").font(.system(size: 8, weight: .bold)).tracking(1.2).foregroundStyle(.white.opacity(0.38))
                }
            }.frame(width: 90, height: 90)
            VStack(alignment: .leading, spacing: 5) {
                Text(session.isActive ? "防睡眠剩余时间" : "防睡眠持续时间").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.44))
                Text(session.isActive ? session.remaining : durationLabel(tab == 0 ? session.selectedMinutes : customDuration)).font(.system(size: 34, weight: .light, design: .rounded).monospacedDigit()).foregroundStyle(.white)
                Text(session.isActive ? "到时恢复系统的自动睡眠设置" : "选好时长后，点击下方按钮开始").font(.system(size: 10)).foregroundStyle(.white.opacity(0.34))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text("防睡眠").font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(.white.opacity(0.33))
                Text(session.isActive ? "计时中" : "未开始").font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(session.isActive ? mint : .white.opacity(0.5))
                if session.isActive { Text("已过 \(Int(session.progress * 100))%").font(.system(size: 10)).foregroundStyle(.white.opacity(0.35)) }
            }
        }.padding(22).background(LinearGradient(colors: [.white.opacity(0.075), .white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.07), lineWidth: 1))
    }

    private var presetGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
            ForEach(session.presets, id: \.1) { item in
                Button { session.selectedMinutes = item.1 } label: {
                    HStack(spacing: 11) {
                        ZStack { RoundedRectangle(cornerRadius: 8).fill(session.selectedMinutes == item.1 ? mint.opacity(0.14) : .white.opacity(0.055)).frame(width: 33, height: 33); Image(systemName: item.1 < 60 ? "timer" : "clock").font(.system(size: 13)).foregroundStyle(session.selectedMinutes == item.1 ? mint : .white.opacity(0.58)) }
                        VStack(alignment: .leading, spacing: 3) { Text(item.0).font(.system(size: 12, weight: .semibold)); Text(item.2).font(.system(size: 9)).foregroundStyle(.white.opacity(0.36)) }
                        Spacer(minLength: 0)
                        if session.selectedMinutes == item.1 { Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(mint) }
                    }.foregroundStyle(.white.opacity(session.selectedMinutes == item.1 ? 1 : 0.78)).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(session.selectedMinutes == item.1 ? mint.opacity(0.065) : .white.opacity(0.025), in: RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(session.selectedMinutes == item.1 ? mint.opacity(0.26) : .white.opacity(0.06), lineWidth: 1))
                }.buttonStyle(.plain).disabled(session.isActive)
            }
        }
    }

    private var customPicker: some View {
        HStack(spacing: 18) {
            timeStepper(title: "小时", value: $session.customHours, range: 0...23)
            timeStepper(title: "分钟", value: $session.customMinutes, range: 0...59)
            Spacer()
            Text("持续 \(durationLabel(customDuration))").font(.system(size: 11, weight: .medium)).foregroundStyle(mint).padding(.horizontal, 13).padding(.vertical, 10).background(mint.opacity(0.08), in: Capsule())
        }.padding(14).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.07), lineWidth: 1))
        .disabled(session.isActive)
    }

    private func timeStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 11) {
                Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1) } label: { Image(systemName: "minus").frame(width: 22, height: 22).background(.white.opacity(0.07), in: Circle()) }
                Text(String(format: "%02d", value.wrappedValue)).font(.system(size: 18, weight: .medium, design: .rounded).monospacedDigit()).foregroundStyle(.white).frame(minWidth: 25)
                Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + 1) } label: { Image(systemName: "plus").frame(width: 22, height: 22).background(.white.opacity(0.07), in: Circle()) }
            }.font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.72)).buttonStyle(.plain)
        }
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button { tab = index } label: { Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(tab == index ? .white : .white.opacity(0.42)).padding(.horizontal, 12).padding(.vertical, 6).background(tab == index ? .white.opacity(0.1) : .clear, in: Capsule()) }.buttonStyle(.plain)
    }
    private var customDuration: Int { max(1, session.customHours * 60 + session.customMinutes) }
    private func durationLabel(_ minutes: Int) -> String { minutes >= 60 ? "\(minutes / 60) 小时\(minutes % 60 == 0 ? "" : " \(minutes % 60) 分钟")" : "\(minutes) 分钟" }
}

struct MenuBarPanel: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var session: WorkSession
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: "hourglass").foregroundStyle(Color.mint); Text("Stilltime").font(.system(size: 13, weight: .semibold)); Spacer(); Text(session.isActive ? "已开启" : "未开启").font(.system(size: 10)).foregroundStyle(.secondary) }
            if session.isActive {
                Text(session.remaining).font(.system(size: 28, weight: .light, design: .rounded).monospacedDigit())
                Button("关闭防睡眠") { session.stop() }.keyboardShortcut(.defaultAction)
            } else {
                Text("点击时长即可开始防睡眠").font(.system(size: 11)).foregroundStyle(.secondary)
                ForEach(session.presets, id: \.1) { item in Button("防睡眠 \(item.0)") { session.start(minutes: item.1) } }
            }
            Divider()
            Button("打开 Stilltime") { openWindow(id: "dashboard"); NSApp.activate(ignoringOtherApps: true) }
            Button("退出") { session.stop(); NSApplication.shared.terminate(nil) }
        }.padding(14).frame(width: 230)
    }
}
