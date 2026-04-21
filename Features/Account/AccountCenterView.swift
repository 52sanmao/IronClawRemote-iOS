import SwiftUI

struct AccountCenterView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClawSpacing.md) {
                centerHeader(title: "账号与安全", subtitle: "展示当前身份、连接状态与后续安全设置入口。") {
                    Button("退出登录") {
                        appState.logout()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClawPalette.danger)
                }

                splitDetailShell {
                    VStack(alignment: .leading, spacing: ClawSpacing.md) {
                        infoPanel(title: "账户信息") {
                            Button {
                            } label: {
                                selectableRow(
                                    title: appState.profile?.displayName ?? "未获取显示名",
                                    subtitle: appState.profile?.email ?? "未提供邮箱",
                                    isSelected: true,
                                    trailing: appState.profile?.role ?? "未知"
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        infoPanel(title: "连接状态") {
                            LabeledValue(label: "网关地址", value: appState.baseURLString)
                            LabeledValue(label: "连接数", value: "\(appState.gatewayStatus?.totalConnections ?? 0)")
                            LabeledValue(label: "版本", value: appState.gatewayStatus?.version ?? "未知")
                        }
                    }
                } detail: {
                    VStack(alignment: .leading, spacing: ClawSpacing.md) {
                        detailCard(
                            title: appState.profile?.displayName ?? "当前账号",
                            badge: appState.profile?.status ?? "未知",
                            lines: [
                                ("用户 ID", appState.profile?.id ?? "未获取"),
                                ("角色", appState.profile?.role ?? "未知"),
                                ("邮箱", appState.profile?.email ?? "未提供"),
                                ("最近登录", appState.profile?.lastLoginAt ?? "未知"),
                                ("创建时间", appState.profile?.createdAt ?? "未知")
                            ],
                            description: "这里是账号二级页，承载 token 管理、安全设置和管理员视角入口。"
                        )

                        infoPanel(title: "安全与连接") {
                            LabeledValue(label: "Token 状态", value: appState.token.isEmpty ? "未保存" : "已保存")
                            LabeledValue(label: "连接通道", value: "SSE \(appState.gatewayStatus?.sseConnections ?? 0) / WS \(appState.gatewayStatus?.wsConnections ?? 0)")
                            LabeledValue(label: "后续入口", value: "安全设置 / 连接测试 / 角色能力")
                        }

                        ProfileEditPanel(appState: appState)

                        TokenManagementPanel(appState: appState)

                        if appState.isAdmin {
                            AdminUserManagementPanel(appState: appState)
                        }
                    }
                }
            }
            .padding(ClawSpacing.md)
        }
        .background(ClawPalette.background)
        .task {
            await AppBootstrapper.refreshTokens(appState: appState)
            if appState.isAdmin {
                await AppBootstrapper.refreshAdminUsers(appState: appState)
            }
        }
    }
}

struct ProfileEditPanel: View {
    @Bindable var appState: AppState
    @State private var displayNameDraft: String = ""

    var body: some View {
        infoPanel(title: "编辑资料") {
            HStack(spacing: ClawSpacing.sm) {
                TextField("显示名", text: $displayNameDraft)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        displayNameDraft = appState.profile?.displayName ?? ""
                    }
                Button("保存") {
                    Task {
                        await AppBootstrapper.updateProfile(appState: appState, displayName: displayNameDraft)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.accent)
                .disabled(displayNameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

struct TokenManagementPanel: View {
    @Bindable var appState: AppState
    @State private var newTokenName: String = ""

    var body: some View {
        infoPanel(title: "API 令牌") {
            if let plaintext = appState.createdTokenPlaintext {
                VStack(alignment: .leading, spacing: ClawSpacing.sm) {
                    Text("新令牌已生成，请立即复制，刷新后不再显示：")
                        .font(.caption)
                        .foregroundStyle(ClawPalette.warning)
                    Text(plaintext)
                        .font(.caption.monospaced())
                        .foregroundStyle(ClawPalette.textPrimary)
                        .textSelection(.enabled)
                        .padding(ClawSpacing.sm)
                        .background(ClawPalette.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Button("我知道了") {
                        appState.createdTokenPlaintext = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClawPalette.accent)
                }
            }

            HStack(spacing: ClawSpacing.sm) {
                TextField("令牌名称", text: $newTokenName)
                    .textFieldStyle(.roundedBorder)
                Button("创建") {
                    Task {
                        await AppBootstrapper.createToken(appState: appState, name: newTokenName)
                        newTokenName = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.accent)
                .disabled(newTokenName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if appState.tokens.isEmpty {
                placeholderText("尚无 API 令牌")
            } else {
                LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                    ForEach(appState.tokens) { token in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(token.name)
                                    .foregroundStyle(ClawPalette.textPrimary)
                                Text("前缀: \(token.tokenPrefix ?? "-") · 创建: \(token.createdAt)")
                                    .font(.caption)
                                    .foregroundStyle(ClawPalette.textSecondary)
                            }
                            Spacer()
                            Button("撤销") {
                                Task {
                                    await AppBootstrapper.revokeToken(appState: appState, tokenID: token.id)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(ClawPalette.danger)
                            .controlSize(.small)
                        }
                        .padding(ClawSpacing.sm)
                        .background(ClawPalette.elevated.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
}

struct AdminUserManagementPanel: View {
    @Bindable var appState: AppState
    @State private var newUserName: String = ""

    var body: some View {
        infoPanel(title: "用户管理 (管理员)") {
            HStack(spacing: ClawSpacing.sm) {
                TextField("新用户显示名", text: $newUserName)
                    .textFieldStyle(.roundedBorder)
                Button("创建") {
                    Task {
                        await AppBootstrapper.createAdminUser(appState: appState, displayName: newUserName)
                        newUserName = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClawPalette.accent)
                .disabled(newUserName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if appState.adminUsers.isEmpty {
                placeholderText("尚未读取用户列表")
            } else {
                LazyVStack(alignment: .leading, spacing: ClawSpacing.sm) {
                    ForEach(appState.adminUsers) { user in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .foregroundStyle(ClawPalette.textPrimary)
                                Text("\(user.role) · \(user.status) · 任务: \(user.jobCount)")
                                    .font(.caption)
                                    .foregroundStyle(ClawPalette.textSecondary)
                            }
                            Spacer()
                            if user.status == "active" {
                                Button("暂停") {
                                    Task {
                                        await AppBootstrapper.suspendAdminUser(appState: appState, userID: user.id)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(ClawPalette.warning)
                                .controlSize(.small)
                            } else {
                                Button("激活") {
                                    Task {
                                        await AppBootstrapper.activateAdminUser(appState: appState, userID: user.id)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(ClawPalette.success)
                                .controlSize(.small)
                            }
                            Button("删除") {
                                Task {
                                    await AppBootstrapper.deleteAdminUser(appState: appState, userID: user.id)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(ClawPalette.danger)
                            .controlSize(.small)
                        }
                        .padding(ClawSpacing.sm)
                        .background(ClawPalette.elevated.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
}