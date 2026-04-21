import SwiftUI

struct LoginView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(colors: [ClawPalette.background, ClawPalette.panel], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: ClawSpacing.lg) {
                VStack(spacing: ClawSpacing.xs) {
                    Text("铁爪远控")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(ClawPalette.textPrimary)
                    Text("原生 iOS 控制端")
                        .foregroundStyle(ClawPalette.textSecondary)
                }

                VStack(alignment: .leading, spacing: ClawSpacing.sm) {
                    Text("网关地址")
                        .foregroundStyle(ClawPalette.textSecondary)
                    TextField("https://rare-lark.agent4.near.ai", text: $appState.baseURLString)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(ClawPalette.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("访问令牌")
                        .foregroundStyle(ClawPalette.textSecondary)
                    SecureField("请输入 Bearer Token", text: $appState.token)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(ClawPalette.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(ClawSpacing.lg)
                .clawCard()

                Button {
                    appState.login()
                } label: {
                    Text("连接到 IronClaw")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ClawPalette.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(32)
            .frame(maxWidth: 460)
        }
    }
}
