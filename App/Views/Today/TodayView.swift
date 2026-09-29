import SwiftUI
import GrooveKit

struct TodayView: View {
    @Environment(GrooveStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(NotificationCoordinator.self) private var notifications
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var tab: Int

    @State private var detail: BlockPayload?
    @State private var logRow: TodayModel.Row?
    @State private var undo: (message: String, blockId: String?, setId: UUID?)?
    @State private var successCount = 0

    var body: some View {
        let _ = store.revision
        TimelineView(.everyMinute) { timeline in
            let model = TodayModel(store: store, settings: settingsStore.settings, now: timeline.date)
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        header(model, now: timeline.date)
                        if model.overflow > 0 {
                            Text(tr("today.overflow", model.overflow))
                                .font(.caption).foregroundStyle(Theme.amber)
                        }
                        if !notifications.isAuthorized && notifications.authorization != .notDetermined {
                            notificationsOff
                        }
                        nextBlockCard(model)
                        if let summary = model.retestSummary { retestCard(model, summary) }
                        if !model.rows.isEmpty { rows(model) }
                    }
                    .padding(16)
                }
                .background(Theme.ground)
                .navigationDestination(for: UUID.self) { programId in
                    ExerciseDetailView(programId: programId)
                }
            }
        }
        .sensoryFeedback(.success, trigger: successCount)
        .sheet(item: $detail) { payload in
            BlockDetailView(payload: payload) { loggedId in
                detail = nil
                if let loggedId { didLog(blockId: loggedId) }
            }
        }
        .sheet(item: $logRow) { row in
            LogSetSheet(row: row) { setId in
                logRow = nil
                successCount += 1
                undo = (tr("today.setLogged"), nil, setId)
                AppEnvironment.shared.dataChanged()
            }
        }
        .onChange(of: notifications.openedBlock, initial: true) { _, payload in
            if let payload { detail = payload; notifications.openedBlock = nil }
        }
        .overlay(alignment: .bottom) {
            if let undo {
                UndoBanner(message: undo.message, onUndo: {
                    if let id = undo.blockId { store.undoBlock(blockId: id) }
                    else if let setId = undo.setId { store.undoSet(id: setId) }
                    self.undo = nil
                    AppEnvironment.shared.dataChanged()
                }, onTimeout: { self.undo = nil })
                .padding(.bottom, 8)
                .id(undo.message + (undo.blockId ?? "") + (undo.setId?.uuidString ?? ""))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: store.revision)
    }

    private func didLog(blockId: String) {
        successCount += 1
        undo = (tr("today.blockLogged"), blockId, nil)
        AppEnvironment.shared.dataChanged()
    }

    private func header(_ model: TodayModel, now: Date) -> some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.caption.weight(.semibold)).tracking(0.8).foregroundStyle(Theme.chalk3)
                Text(tr("tab.today")).font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.chalk)
            }
            Spacer()
            Text(tr("today.streak", model.streak))
                .font(.subheadline.weight(.bold)).monospacedDigit()
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Theme.surface, in: Capsule())
                .foregroundStyle(Theme.chalk)
        }
    }

    private var notificationsOff: some View {
        HStack {
            Text(tr("today.notifDenied")).font(.subheadline).foregroundStyle(Theme.chalk2)
            Spacer()
            Button(tr("today.openSettings")) {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
            }
            .font(.subheadline.weight(.semibold))
        }
        .card()
    }

    @ViewBuilder
    private func nextBlockCard(_ model: TodayModel) -> some View {
        if model.rows.isEmpty {
            Text(tr("today.empty")).foregroundStyle(Theme.chalk2).card()
        } else if model.isRestDay {
            Text(tr("today.restDay")).foregroundStyle(Theme.chalk2).card()
        } else if let block = model.nextBlock {
            let items = NotificationText.items(for: block, store: store, locale: .current)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(tr("today.nextBlock").uppercased())
                        .font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(Theme.berry)
                    Spacer()
                    Text(block.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption).monospacedDigit().foregroundStyle(Theme.chalk3)
                }
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.name).foregroundStyle(Theme.chalk)
                        if item.perSide { Text(tr("unit.perSide")).foregroundStyle(Theme.chalk3) }
                        Spacer()
                        Text(verbatim: "\(item.reps)\(item.unit == .seconds ? " " + tr("unit.seconds") : "")")
                            .font(Theme.counter(18)).foregroundStyle(Theme.chalk)
                    }
                }
                HStack(spacing: 8) {
                    Button {
                        if store.logBlock(BlockPayload(block: block), at: .now) { didLog(blockId: block.id) }
                    } label: {
                        Text(tr("action.done")).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.berry, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Theme.onBerry)
                    }
                    Button {
                        store.skipBlock(BlockPayload(block: block), at: .now)
                        AppEnvironment.shared.dataChanged()
                    } label: {
                        Text(tr("action.skip")).font(.headline).padding(.vertical, 12).padding(.horizontal, 18)
                            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Theme.chalk2)
                    }
                }
            }
            .card()
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.berry.opacity(0.25)))
            .onTapGesture { detail = BlockPayload(block: block) }
            .accessibilityAction(named: Text(tr("today.openBlock"))) { detail = BlockPayload(block: block) }
        } else {
            Text(tr("today.noMoreBlocks")).foregroundStyle(Theme.chalk2).card()
        }
    }

    @ViewBuilder
    private func retestCard(_ model: TodayModel, _ summary: String) -> some View {
        let label = Text(tr("today.retestDueMany", summary))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.chalk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.amber.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.amber.opacity(0.4)))
        if model.retestDue.count == 1, let row = model.retestDue.first {
            NavigationLink(value: row.program.id) { label }
        } else {
            Button { tab = 1 } label: { label }
                .buttonStyle(.plain)
        }
    }

    private func rows(_ model: TodayModel) -> some View {
        VStack(spacing: 0) {
            ForEach(model.rows) { row in
                Button { logRow = row } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(row.exercise.displayName()).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.chalk)
                            Spacer()
                            Text(tr("today.count", row.done, row.goal))
                                .font(.caption).monospacedDigit()
                                .foregroundStyle(row.done >= row.goal ? Theme.mint : Theme.chalk3)
                        }
                        TallyView(done: Double(min(row.done, row.goal)), goal: row.goal)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if row.id != model.rows.last?.id { Divider().overlay(Theme.line) }
            }
            if !model.rows.isEmpty {
                Text(tr("today.total", model.totalDone, model.totalGoal))
                    .font(.caption).monospacedDigit().foregroundStyle(Theme.chalk3)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension BlockPayload: @retroactive Identifiable {
    public var id: String { blockId }
}
