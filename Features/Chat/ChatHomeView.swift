import SwiftUI
import PhotosUI

struct ChatHomeView: View {
    @Bindable var appState: AppState
    @State private var isResolvingGate = false
    @State private var showGateParameters = false
    @State private var isSubmittingAuth = false
    @State private var authTokenDraft: String = ""
    @State private var showSlashMenu = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider().overlay(ClawPalette.stroke)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ClawSpacing.md) {
                        if let auth = appState.pendingAuth {
                            authCard(auth)
                        }

                        if let gate = appState.pendingGate {
                            gateCard(gate)
                        }

                        if let approval = appState.pendingApproval {
                            approvalCard(approval)
                        }

                        if !appState.inspectorEvents.isEmpty {
                            timelineEventsCard
                        }

                        if appState.turns.isEmpty && appState.streamingText.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(appState.turns.enumerated()), id: \.offset) { item in
                                TurnCard(turn: item.element)
                            }

                            if !appState.streamingText.isEmpty {
                                streamingCard
                                    .id("streaming")
                            }
                        }
                    }
                    .padding(ClawSpacing.md)
                }
                .onChange(of: appState.streamingText) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
            Divider().overlay(ClawPalette.stroke)
            composer
        }
        .background(ClawPalette.background)
    }

    private var chatHeader: some View {
        HStack(alignment: .top, spacing: ClawSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentTitle)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(ClawPalette.textPrimary)
                HStack(spacing: ClawSpacing.sm) {
                    statusPill(text: appState.statusText, color: .accent)
                    if let model = appState.gatewayStatus?.llmModel, !model.isEmpty {
                        statusPill(text: model, color: .secondary)
                    }
                    if let channel = currentThread?.channel, !channel.isEmpty {
                        statusPill(text: channel.uppercased(), color: .secondary)
                    }
                    if appState.pendingGate != nil || appState.pendingApproval != nil {
                        statusPill(text: "待确认", color: .warning)
                    }
                    if appState.pendingAuth != nil {
                        statusPill(text: "待认证", color: .warning)
                    }
                }
            }

            Spacer()

            HStack(spacing: ClawSpacing.sm) {
                Button("新建会话") {
                    Task { await AppBootstrapper.createNewThread(appState: appState) }
                }
                .buttonStyle(.bordered)

                Button("刷新") {
                    Task { await AppBootstrapper.refreshThreads(appState: appState) }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.accent)
            }
        }
        .padding(ClawSpacing.md)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            Text("聊天主窗")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ClawPalette.textPrimary)
            Text("这里会持续展示线程历史、流式回复、工具结果与人工确认。先从左侧选择会话，或直接发送一条消息开始。")
                .foregroundStyle(ClawPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ClawSpacing.lg)
        .clawCard()
    }

    private func authCard(_ auth: AuthRequiredEvent) -> some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            Label("需要认证", systemImage: "lock.shield.fill")
                .foregroundStyle(ClawPalette.warning)
                .font(.headline)
            LabeledValue(label: "扩展", value: auth.extensionName)
            if let instructions = auth.instructions, !instructions.isEmpty {
                Text(instructions)
                    .foregroundStyle(ClawPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let authURL = auth.authURL, !authURL.isEmpty {
                Link("前往 OAuth 认证", destination: URL(string: authURL) ?? URL(string: "https://example.com")!)
                    .font(.footnote)
            }
            if let setupURL = auth.setupURL, !setupURL.isEmpty {
                Link("获取令牌", destination: URL(string: setupURL) ?? URL(string: "https://example.com")!)
                    .font(.footnote)
            }
            TextField("粘贴令牌", text: $authTokenDraft)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: ClawSpacing.sm) {
                Button(isSubmittingAuth ? "提交中..." : "提交令牌") {
                    Task {
                        isSubmittingAuth = true
                        defer { isSubmittingAuth = false }
                        await AppBootstrapper.submitAuthToken(
                            appState: appState,
                            extensionName: auth.extensionName,
                            token: authTokenDraft,
                            requestID: nil,
                            threadID: auth.threadId
                        )
                        authTokenDraft = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.success)
                .disabled(authTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingAuth)

                Button("取消") {
                    Task { await AppBootstrapper.cancelAuth(appState: appState, extensionName: auth.extensionName, requestID: nil, threadID: auth.threadId) }
                }
                .buttonStyle(.bordered)
                .tint(ClawPalette.warning)
            }
        }
        .padding(ClawSpacing.md)
        .clawCard()
    }

    private func gateCard(_ gate: PendingGateInfo) -> some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            Label("需要人工确认", systemImage: "hand.raised.fill")
                .foregroundStyle(ClawPalette.warning)
                .font(.headline)
            LabeledValue(label: "确认项", value: gate.gateName)
            LabeledValue(label: "工具", value: gate.toolName)
            Text(gate.description)
                .foregroundStyle(ClawPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Button(showGateParameters ? "隐藏参数" : "显示参数") {
                showGateParameters.toggle()
            }
            .buttonStyle(.bordered)

            if showGateParameters {
                Text(gate.parameters)
                    .font(.footnote.monospaced())
                    .foregroundStyle(ClawPalette.textSecondary)
                    .padding(ClawSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ClawPalette.elevated.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: ClawSpacing.sm) {
                Button(isResolvingGate ? "提交中..." : "批准") {
                    Task { await resolveGate(gate, resolution: .approved(always: false)) }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.success)
                .disabled(isResolvingGate)

                Button(isResolvingGate ? "提交中..." : "始终允许") {
                    Task { await resolveGate(gate, resolution: .approved(always: true)) }
                }
                .buttonStyle(.bordered)
                .disabled(isResolvingGate)

                Button(isResolvingGate ? "提交中..." : "拒绝") {
                    Task { await resolveGate(gate, resolution: .denied) }
                }
                .buttonStyle(.bordered)
                .tint(ClawPalette.warning)
                .disabled(isResolvingGate)
            }
        }
        .padding(ClawSpacing.md)
        .clawCard()
    }

    private func approvalCard(_ approval: ApprovalNeededEvent) -> some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            Label("工具需要审批", systemImage: "checkmark.shield.fill")
                .foregroundStyle(ClawPalette.warning)
                .font(.headline)
            LabeledValue(label: "工具", value: approval.toolName)
            Text(approval.description)
                .foregroundStyle(ClawPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(approval.parameters)
                .font(.footnote.monospaced())
                .foregroundStyle(ClawPalette.textSecondary)
                .padding(ClawSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ClawPalette.elevated.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: ClawSpacing.sm) {
                Button("批准") {
                    Task { await AppBootstrapper.resolveApproval(appState: appState, requestID: approval.requestId, threadID: approval.threadId, action: "approve") }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.success)

                if approval.allowAlways {
                    Button("始终允许") {
                        Task { await AppBootstrapper.resolveApproval(appState: appState, requestID: approval.requestId, threadID: approval.threadId, action: "always") }
                    }
                    .buttonStyle(.bordered)
                }

                Button("拒绝") {
                    Task { await AppBootstrapper.resolveApproval(appState: appState, requestID: approval.requestId, threadID: approval.threadId, action: "deny") }
                }
                .buttonStyle(.bordered)
                .tint(ClawPalette.warning)
            }
        }
        .padding(ClawSpacing.md)
        .clawCard()
    }

    private var timelineEventsCard: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            Text("执行时间线")
                .font(.headline)
                .foregroundStyle(ClawPalette.textPrimary)
            ForEach(Array(appState.inspectorEvents.prefix(8).enumerated()), id: \.offset) { _, event in
                Text(event)
                    .font(.footnote)
                    .foregroundStyle(ClawPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            }
        }
        .padding(ClawSpacing.md)
        .clawCard()
    }

    private var streamingCard: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            Text("实时回复中")
                .font(.headline)
                .foregroundStyle(ClawPalette.accent)
            Text(appState.streamingText)
                .foregroundStyle(ClawPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ClawSpacing.md)
        .clawCard()
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.sm) {
            if !appState.draftImages.isEmpty {
                HStack(spacing: ClawSpacing.sm) {
                    Text("已选图片：\(appState.draftImages.count) 张")
                        .font(.caption)
                        .foregroundStyle(ClawPalette.textSecondary)
                    Button("清空") { appState.draftImages = [] }
                        .font(.caption)
                }
            }

            HStack(spacing: ClawSpacing.sm) {
                Menu {
                    ForEach(SlashCommand.allCases, id: \.self) { cmd in
                        Button {
                            appState.draftMessage = cmd.rawValue + " "
                        } label: {
                            Text(cmd.rawValue)
                        }
                    }
                } label: {
                    Image(systemName: "command")
                        .foregroundStyle(ClawPalette.accent)
                        .padding(8)
                        .background(ClawPalette.elevated)
                        .clipShape(Circle())
                }

                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 4, matching: .images) {
                    Image(systemName: "photo")
                        .foregroundStyle(ClawPalette.accent)
                        .padding(8)
                        .background(ClawPalette.elevated)
                        .clipShape(Circle())
                }
                .onChange(of: selectedPhotoItems) { _, items in
                    Task { await loadSelectedPhotos(items) }
                }

                TextField("输入消息、指令或补充说明", text: $appState.draftMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(ClawPalette.textPrimary)
                    .padding(ClawSpacing.md)
                    .background(ClawPalette.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button {
                    Task { await AppBootstrapper.sendMessage(appState: appState) }
                } label: {
                    Text("发送")
                        .fontWeight(.semibold)
                        .padding(.horizontal, ClawSpacing.lg)
                        .padding(.vertical, ClawSpacing.md)
                        .background(ClawPalette.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(appState.pendingGate != nil || appState.pendingApproval != nil || appState.pendingAuth != nil)
                .opacity((appState.pendingGate == nil && appState.pendingApproval == nil && appState.pendingAuth == nil) ? 1 : 0.55)
            }
        }
        .padding(ClawSpacing.md)
        .background(ClawPalette.panel.opacity(0.95))
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var payloads: [ImagePayload] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let mime = data.isPNG ? "image/png" : "image/jpeg"
                let base64 = data.base64EncodedString()
                payloads.append(ImagePayload(mediaType: mime, data: base64))
            }
        }
        await MainActor.run {
            appState.draftImages = payloads
            selectedPhotoItems = []
        }
    }

    private func resolveGate(_ gate: PendingGateInfo, resolution: GateResolutionPayload) async {
        isResolvingGate = true
        defer { isResolvingGate = false }
        await AppBootstrapper.resolveGate(appState: appState, requestID: gate.requestId, threadID: gate.threadId, resolution: resolution)
    }

    private func statusPill(text: String, color: PillColor) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color.foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.background)
            .clipShape(Capsule())
    }

    private var currentThread: ThreadInfo? {
        if let assistant = appState.assistantThread, assistant.id == appState.currentThreadID {
            return assistant
        }
        return appState.threads.first { $0.id == appState.currentThreadID }
    }

    private var currentTitle: String {
        if appState.selectedDestination == .newConversation {
            return "新建会话"
        }
        return currentThread?.title ?? (currentThread?.threadType == "assistant" ? "助手会话" : "聊天")
    }
}

private struct TurnCard: View {
    let turn: TurnInfo

    var body: some View {
        VStack(alignment: .leading, spacing: ClawSpacing.md) {
            VStack(alignment: .leading, spacing: ClawSpacing.sm) {
                Text("你")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ClawPalette.textSecondary)
                Text(turn.userInput)
                    .foregroundStyle(ClawPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ClawSpacing.md)
                    .background(ClawPalette.elevated.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: ClawRadius.bubble, style: .continuous))
            }

            VStack(alignment: .leading, spacing: ClawSpacing.sm) {
                HStack {
                    Text("IronClaw")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ClawPalette.accent)
                    Spacer()
                    Text(turn.state)
                        .font(.caption2)
                        .foregroundStyle(ClawPalette.textSecondary)
                }

                if let response = turn.response, !response.isEmpty {
                    Text(response)
                        .foregroundStyle(ClawPalette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let narrative = turn.narrative, !narrative.isEmpty {
                    Text(narrative)
                        .font(.footnote)
                        .foregroundStyle(ClawPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !turn.toolCalls.isEmpty {
                    VStack(alignment: .leading, spacing: ClawSpacing.xs) {
                        Text("工具调用")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(ClawPalette.textSecondary)
                        ForEach(Array(turn.toolCalls.enumerated()), id: \.offset) { item in
                            let tool = item.element
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    Text(tool.name)
                                        .foregroundStyle(ClawPalette.textPrimary)
                                    Spacer()
                                    Text(tool.hasError ? "失败" : (tool.hasResult ? "已完成" : "进行中"))
                                        .foregroundStyle(tool.hasError ? ClawPalette.danger : ClawPalette.success)
                                }
                                .font(.footnote)
                                if let rationale = tool.rationale, !rationale.isEmpty {
                                    Text(rationale)
                                        .font(.caption)
                                        .foregroundStyle(ClawPalette.textSecondary)
                                }
                                if let preview = tool.resultPreview, !preview.isEmpty {
                                    Text(preview)
                                        .font(.caption)
                                        .foregroundStyle(ClawPalette.textPrimary)
                                        .lineLimit(4)
                                }
                                if let error = tool.error, !error.isEmpty {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(ClawPalette.danger)
                                        .lineLimit(4)
                                }
                            }
                        }
                    }
                    .padding(ClawSpacing.sm)
                    .background(ClawPalette.elevated.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if !turn.generatedImages.isEmpty {
                    Text("已生成图片：\(turn.generatedImages.count) 张")
                        .font(.footnote)
                        .foregroundStyle(ClawPalette.textSecondary)
                }
            }
            .padding(ClawSpacing.md)
            .clawCard()
        }
    }
}

private enum PillColor {
    case accent
    case secondary
    case warning

    var foreground: Color {
        switch self {
        case .accent, .warning: return .white
        case .secondary: return ClawPalette.textPrimary
        }
    }

    var background: Color {
        switch self {
        case .accent: return ClawPalette.accent
        case .secondary: return ClawPalette.elevated
        case .warning: return ClawPalette.warning
        }
    }
}

private enum SlashCommand: String, CaseIterable {
    case status = "/status"
    case list = "/list"
    case cancel = "/cancel"
    case undo = "/undo"
    case redo = "/redo"
    case compact = "/compact"
    case clear = "/clear"
    case interrupt = "/interrupt"
    case heartbeat = "/heartbeat"
    case summarize = "/summarize"
    case suggest = "/suggest"
    case help = "/help"
    case version = "/version"
    case tools = "/tools"
}

private extension Data {
    var isPNG: Bool {
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        guard count >= pngSignature.count else { return false }
        return pngSignature.withUnsafeBufferPointer { sig in
            self.withUnsafeBytes { bytes in
                memcmp(bytes.baseAddress!, sig.baseAddress!, sig.count) == 0
            }
        }
    }
}
