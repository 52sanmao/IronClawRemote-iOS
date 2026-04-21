import Foundation

enum AppBootstrapper {
    static func bootstrap(appState: AppState) async {
        await refreshProfile(appState: appState)
        await refreshGatewayStatus(appState: appState)
        await refreshThreads(appState: appState)
        await refreshMemory(appState: appState)
        await refreshJobs(appState: appState)
        await refreshRoutines(appState: appState)
        await refreshMissions(appState: appState)
        await refreshProviders(appState: appState)
        await refreshLogLevel(appState: appState)
        connectChatEvents(appState: appState)
        connectLogEvents(appState: appState)
    }

    static func refreshProfile(appState: AppState) async {
        do {
            let profile: ProfileResponse = try await APIClient.shared.request(path: "api/profile")
            appState.profile = profile
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshGatewayStatus(appState: AppState) async {
        do {
            let status: GatewayStatusResponse = try await APIClient.shared.request(path: "api/gateway/status")
            appState.gatewayStatus = status
        } catch {}
    }

    static func refreshThreads(appState: AppState) async {
        do {
            let response: ThreadListResponse = try await APIClient.shared.request(path: "api/chat/threads")
            let previousThreadID = appState.currentThreadID
            appState.assistantThread = response.assistantThread
            appState.threads = response.threads
            appState.currentThreadID = previousThreadID
                .flatMap { threadID in
                    let threadExists = response.assistantThread?.id == threadID || response.threads.contains { $0.id == threadID }
                    return threadExists ? threadID : nil
                }
                ?? response.activeThread
                ?? response.assistantThread?.id
                ?? response.threads.first?.id
            if let threadID = appState.currentThreadID {
                await refreshHistory(appState: appState, threadID: threadID)
            }
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshHistory(appState: AppState, threadID: UUID) async {
        do {
            let history: HistoryResponse = try await APIClient.shared.request(path: "api/chat/history", queryItems: [
                URLQueryItem(name: "thread_id", value: threadID.uuidString),
                URLQueryItem(name: "limit", value: "50")
            ])
            appState.turns = history.turns
            appState.pendingGate = history.pendingGate
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func createNewThread(appState: AppState) async {
        do {
            let thread: ThreadInfo = try await APIClient.shared.request(path: "api/chat/thread/new", method: "POST")
            appState.currentThreadID = thread.id
            appState.currentPane = .chat
            appState.selectedDestination = .conversations
            appState.turns = []
            appState.pendingGate = nil
            appState.streamingText = ""
            appState.statusText = "已创建新会话"
            await refreshThreads(appState: appState)
            appState.currentThreadID = thread.id
            await refreshHistory(appState: appState, threadID: thread.id)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshMemory(appState: AppState) async {
        do {
            let list: MemoryListResponse = try await APIClient.shared.request(path: "api/memory/list")
            appState.memoryEntries = list.entries
        } catch {}
    }

    static func readMemoryFile(appState: AppState, path: String) async {
        do {
            let response: MemoryReadResponse = try await APIClient.shared.request(
                path: "api/memory/read",
                queryItems: [URLQueryItem(name: "path", value: path)]
            )
            appState.selectedMemoryFile = response
            appState.selectedMemoryPath = response.path
            appState.memoryEditorContent = response.content
            appState.statusText = "已读取记忆文件"
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func writeMemoryFile(appState: AppState, path: String, content: String) async {
        do {
            let data = try JSONEncoder().encode(MemoryWriteRequest(path: path, content: content, append: nil, force: nil, layer: nil))
            let _: MemoryWriteResponse = try await APIClient.shared.request(path: "api/memory/write", method: "POST", body: data)
            appState.statusText = "已保存记忆文件"
            await readMemoryFile(appState: appState, path: path)
            await refreshMemory(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func searchMemory(appState: AppState) async {
        guard !appState.memorySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            appState.memorySearchResults = []
            return
        }
        do {
            let data = try JSONEncoder().encode(MemorySearchRequest(query: appState.memorySearchQuery, limit: 20))
            let response: MemorySearchResponse = try await APIClient.shared.request(path: "api/memory/search", method: "POST", body: data)
            appState.memorySearchResults = response.results
            appState.statusText = "已完成记忆搜索"
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshJobs(appState: AppState) async {
        do {
            async let list: JobListResponse = APIClient.shared.request(path: "api/jobs")
            async let summary: JobSummaryResponse = APIClient.shared.request(path: "api/jobs/summary")
            appState.jobs = try await list.jobs
            appState.jobSummary = try await summary
            if let selectedJobID = appState.selectedJobID ?? appState.jobs.first?.id {
                appState.selectedJobID = selectedJobID
                await loadJobDetail(appState: appState, jobID: selectedJobID)
            }
        } catch {}
    }

    static func loadJobDetail(appState: AppState, jobID: UUID) async {
        do {
            async let detail: JobDetailResponse = APIClient.shared.request(path: "api/jobs/\(jobID.uuidString)")
            async let events: JobEventsResponse = APIClient.shared.request(path: "api/jobs/\(jobID.uuidString)/events")
            async let files: ProjectFilesResponse = APIClient.shared.request(path: "api/jobs/\(jobID.uuidString)/files/list", queryItems: [URLQueryItem(name: "path", value: "")])
            appState.selectedJobDetail = try await detail
            appState.selectedJobEvents = try await events.events
            appState.selectedJobFileEntries = try await files.entries
            appState.selectedJobFilePath = nil
            appState.selectedJobFileContent = nil
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func loadJobFile(appState: AppState, jobID: UUID, path: String) async {
        do {
            let response: ProjectFileReadResponse = try await APIClient.shared.request(
                path: "api/jobs/\(jobID.uuidString)/files/read",
                queryItems: [URLQueryItem(name: "path", value: path)]
            )
            appState.selectedJobFilePath = path
            appState.selectedJobFileContent = response
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func cancelJob(appState: AppState, jobID: UUID) async {
        do {
            let _: JobActionResponse = try await APIClient.shared.request(path: "api/jobs/\(jobID.uuidString)/cancel", method: "POST")
            appState.statusText = "任务已取消"
            await refreshJobs(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func restartJob(appState: AppState, jobID: UUID) async {
        do {
            let _: JobActionResponse = try await APIClient.shared.request(path: "api/jobs/\(jobID.uuidString)/restart", method: "POST")
            appState.statusText = "任务已重启"
            await refreshJobs(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func sendJobPrompt(appState: AppState, jobID: UUID) async {
        guard !appState.jobPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(JobPromptRequest(content: appState.jobPromptDraft, done: false))
            let _: JobActionResponse = try await APIClient.shared.request(path: "api/jobs/\(jobID.uuidString)/prompt", method: "POST", body: data)
            appState.jobPromptDraft = ""
            appState.statusText = "已发送跟进提示"
            await loadJobDetail(appState: appState, jobID: jobID)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshRoutines(appState: AppState) async {
        do {
            async let list: RoutineListResponse = APIClient.shared.request(path: "api/routines")
            async let summary: RoutineSummaryResponse = APIClient.shared.request(path: "api/routines/summary")
            appState.routines = try await list.routines
            appState.routineSummary = try await summary
            if let selectedRoutineID = appState.selectedRoutineID ?? appState.routines.first?.id {
                appState.selectedRoutineID = selectedRoutineID
                await loadRoutineDetail(appState: appState, routineID: selectedRoutineID)
            }
        } catch {}
    }

    static func loadRoutineDetail(appState: AppState, routineID: UUID) async {
        do {
            async let detail: RoutineDetailResponse = APIClient.shared.request(path: "api/routines/\(routineID.uuidString)")
            async let runs: RoutineRunsResponse = APIClient.shared.request(path: "api/routines/\(routineID.uuidString)/runs")
            appState.selectedRoutineDetail = try await detail
            appState.routineRuns = try await runs.runs
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func triggerRoutine(appState: AppState, routineID: UUID) async {
        do {
            let _: RoutineActionResponse = try await APIClient.shared.request(path: "api/routines/\(routineID.uuidString)/trigger", method: "POST")
            appState.statusText = "已手动触发定时器"
            await loadRoutineDetail(appState: appState, routineID: routineID)
            await refreshRoutines(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func toggleRoutine(appState: AppState, routineID: UUID, enabled: Bool? = nil) async {
        do {
            let body = enabled.map { ["enabled": $0] }
            let data = try body.map { try JSONSerialization.data(withJSONObject: $0) }
            let _: RoutineActionResponse = try await APIClient.shared.request(path: "api/routines/\(routineID.uuidString)/toggle", method: "POST", body: data)
            appState.statusText = "已更新定时器状态"
            await loadRoutineDetail(appState: appState, routineID: routineID)
            await refreshRoutines(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func deleteRoutine(appState: AppState, routineID: UUID) async {
        do {
            let _: RoutineActionResponse = try await APIClient.shared.request(path: "api/routines/\(routineID.uuidString)", method: "DELETE")
            appState.statusText = "已删除定时器"
            appState.selectedRoutineID = nil
            appState.selectedRoutineDetail = nil
            appState.routineRuns = []
            await refreshRoutines(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshMissions(appState: AppState) async {
        do {
            async let list: EngineMissionListResponse = APIClient.shared.request(path: "api/engine/missions")
            async let summary: EngineMissionSummaryResponse = APIClient.shared.request(path: "api/engine/missions/summary")
            appState.missions = try await list.missions
            appState.missionSummary = try await summary
            if let selectedMissionID = appState.selectedMissionID ?? appState.missions.first?.id {
                appState.selectedMissionID = selectedMissionID
                await loadMissionDetail(appState: appState, missionID: selectedMissionID)
            }
        } catch {}
    }

    static func loadMissionDetail(appState: AppState, missionID: String) async {
        do {
            let response: EngineMissionDetailResponse = try await APIClient.shared.request(path: "api/engine/missions/\(missionID)")
            appState.selectedMissionDetail = response.mission.prettyString
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func fireMission(appState: AppState, missionID: String) async {
        do {
            let response: EngineMissionFireResponse = try await APIClient.shared.request(path: "api/engine/missions/\(missionID)/fire", method: "POST")
            appState.statusText = response.fired ? "任务流已触发" : "任务流未触发"
            await loadMissionDetail(appState: appState, missionID: missionID)
            await refreshMissions(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func pauseMission(appState: AppState, missionID: String) async {
        do {
            let _: EngineActionResponse = try await APIClient.shared.request(path: "api/engine/missions/\(missionID)/pause", method: "POST")
            appState.statusText = "任务流已暂停"
            await loadMissionDetail(appState: appState, missionID: missionID)
            await refreshMissions(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func resumeMission(appState: AppState, missionID: String) async {
        do {
            let _: EngineActionResponse = try await APIClient.shared.request(path: "api/engine/missions/\(missionID)/resume", method: "POST")
            appState.statusText = "任务流已恢复"
            await loadMissionDetail(appState: appState, missionID: missionID)
            await refreshMissions(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshEngineThreads(appState: AppState) async {
        do {
            let response: EngineThreadListResponse = try await APIClient.shared.request(path: "api/engine/threads")
            appState.engineThreads = response.threads
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func loadEngineThreadDetail(appState: AppState, threadID: String) async {
        do {
            async let detail: EngineThreadDetailResponse = APIClient.shared.request(path: "api/engine/threads/\(threadID)")
            async let steps: EngineStepListResponse = APIClient.shared.request(path: "api/engine/threads/\(threadID)/steps")
            async let events: EngineEventListResponse = APIClient.shared.request(path: "api/engine/threads/\(threadID)/events")
            let _: EngineThreadDetailResponse = try await detail
            appState.engineThreadSteps = try await steps.steps
            appState.engineThreadEvents = try await events.events
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshTokens(appState: AppState) async {
        do {
            let response: TokenListResponse = try await APIClient.shared.request(path: "api/tokens")
            appState.tokens = response.tokens
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func createToken(appState: AppState, name: String, expiresInDays: Int? = nil) async {
        do {
            var body: [String: Any] = ["name": name]
            if let days = expiresInDays { body["expires_in_days"] = days }
            let data = try JSONSerialization.data(withJSONObject: body)
            let response: TokenCreateResponse = try await APIClient.shared.request(path: "api/tokens", method: "POST", body: data)
            appState.createdTokenPlaintext = response.token
            appState.statusText = "令牌已创建，请立即复制"
            await refreshTokens(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func revokeToken(appState: AppState, tokenID: String) async {
        do {
            let _: TokenRevokeResponse = try await APIClient.shared.request(path: "api/tokens/\(tokenID)", method: "DELETE")
            appState.statusText = "令牌已撤销"
            await refreshTokens(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshAdminUsers(appState: AppState) async {
        do {
            let response: AdminUserListResponse = try await APIClient.shared.request(path: "api/admin/users")
            appState.adminUsers = response.users
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func createAdminUser(appState: AppState, displayName: String, role: String = "member") async {
        do {
            let data = try JSONSerialization.data(withJSONObject: ["display_name": displayName, "role": role])
            let response: AdminUserCreateResponse = try await APIClient.shared.request(path: "api/admin/users", method: "POST", body: data)
            appState.statusText = "用户已创建: \(response.displayName)，令牌: \(response.token)"
            await refreshAdminUsers(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func suspendAdminUser(appState: AppState, userID: String) async {
        do {
            let _: AdminUserStatusResponse = try await APIClient.shared.request(path: "api/admin/users/\(userID)/suspend", method: "POST")
            appState.statusText = "用户已暂停"
            await refreshAdminUsers(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func activateAdminUser(appState: AppState, userID: String) async {
        do {
            let _: AdminUserStatusResponse = try await APIClient.shared.request(path: "api/admin/users/\(userID)/activate", method: "POST")
            appState.statusText = "用户已激活"
            await refreshAdminUsers(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func deleteAdminUser(appState: AppState, userID: String) async {
        do {
            let _: AdminUserDeleteResponse = try await APIClient.shared.request(path: "api/admin/users/\(userID)", method: "DELETE")
            appState.statusText = "用户已删除"
            appState.selectedAdminUserID = nil
            await refreshAdminUsers(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshEngineProjects(appState: AppState) async {
        do {
            let response: EngineProjectListResponse = try await APIClient.shared.request(path: "api/engine/projects")
            appState.engineProjects = response.projects
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshProviders(appState: AppState) async {
        do {
            let providers: [LLMProviderInfo] = try await APIClient.shared.request(path: "api/llm/providers")
            appState.providers = providers
        } catch {}
    }

    static func refreshLogLevel(appState: AppState) async {
        do {
            let response: LogLevelResponse = try await APIClient.shared.request(path: "api/logs/level")
            appState.logLevel = response.level
        } catch {}
    }

    static func setLogLevel(appState: AppState, level: String) async {
        do {
            let data = try JSONSerialization.data(withJSONObject: ["level": level])
            let _: Data = try await APIClient.shared.request(path: "api/logs/level", method: "PUT", body: data)
            appState.logLevel = level
            appState.statusText = "日志级别已设置为 \(level)"
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func updateProfile(appState: AppState, displayName: String) async {
        do {
            let data = try JSONSerialization.data(withJSONObject: ["display_name": displayName])
            let _: ProfileResponse = try await APIClient.shared.request(path: "api/profile", method: "PATCH", body: data)
            appState.statusText = "个人资料已更新"
            await refreshProfile(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshSettings(appState: AppState) async {
        do {
            let response: SettingsExportResponse = try await APIClient.shared.request(path: "api/settings/export")
            appState.settingsMap = response.settings
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func setSetting(appState: AppState, key: String, value: JSONValue) async {
        do {
            let data = try JSONEncoder().encode(SettingWriteRequest(value: value))
            let _: Data = try await APIClient.shared.request(path: "api/settings/\(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key)", method: "PUT", body: data)
            appState.statusText = "设置已保存"
            await refreshSettings(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func deleteSetting(appState: AppState, key: String) async {
        do {
            let _: Data = try await APIClient.shared.request(path: "api/settings/\(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key)", method: "DELETE")
            appState.statusText = "设置已删除"
            appState.selectedSettingKey = nil
            await refreshSettings(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshToolPermissions(appState: AppState) async {
        do {
            let response: ToolPermissionsResponse = try await APIClient.shared.request(path: "api/settings/tools")
            appState.toolPermissions = response.tools
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func updateToolPermission(appState: AppState, toolName: String, state: String) async {
        do {
            let data = try JSONEncoder().encode(UpdateToolPermissionRequest(state: state))
            let _: ToolPermissionEntry = try await APIClient.shared.request(path: "api/settings/tools/\(toolName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? toolName)", method: "PUT", body: data)
            appState.statusText = "工具权限已更新"
            await refreshToolPermissions(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshExtensions(appState: AppState) async {
        do {
            let response: ExtensionListResponse = try await APIClient.shared.request(path: "api/extensions")
            appState.extensions = response.extensions
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshRegistry(appState: AppState) async {
        do {
            let response: RegistrySearchResponse = try await APIClient.shared.request(path: "api/extensions/registry")
            appState.registryEntries = response.entries
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func installExtension(appState: AppState, name: String, url: String? = nil, kind: String? = nil) async {
        do {
            let data = try JSONEncoder().encode(InstallExtensionRequest(name: name, url: url, kind: kind))
            let _: ActionResponse = try await APIClient.shared.request(path: "api/extensions/install", method: "POST", body: data)
            appState.statusText = "扩展安装请求已发送"
            await refreshExtensions(appState: appState)
            await refreshRegistry(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func activateExtension(appState: AppState, name: String) async {
        do {
            let _: ActionResponse = try await APIClient.shared.request(path: "api/extensions/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)/activate", method: "POST")
            appState.statusText = "扩展已激活"
            await refreshExtensions(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func removeExtension(appState: AppState, name: String) async {
        do {
            let _: ActionResponse = try await APIClient.shared.request(path: "api/extensions/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)/remove", method: "POST")
            appState.statusText = "扩展已移除"
            appState.selectedExtensionName = nil
            await refreshExtensions(appState: appState)
            await refreshRegistry(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func loadExtensionSetup(appState: AppState, name: String) async {
        do {
            let response: ExtensionSetupResponse = try await APIClient.shared.request(path: "api/extensions/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)/setup")
            appState.extensionSetup = response
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func submitExtensionSetup(appState: AppState, name: String, secrets: [String: String], fields: [String: String]) async {
        do {
            let data = try JSONEncoder().encode(ExtensionSetupRequest(secrets: secrets, fields: fields))
            let _: ActionResponse = try await APIClient.shared.request(path: "api/extensions/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)/setup", method: "POST", body: data)
            appState.statusText = "扩展配置已保存"
            appState.extensionSetup = nil
            await refreshExtensions(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func refreshSkills(appState: AppState) async {
        do {
            let response: SkillListResponse = try await APIClient.shared.request(path: "api/skills")
            appState.skills = response.skills
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func searchSkills(appState: AppState) async {
        guard !appState.skillSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            appState.skillSearchResults = []
            return
        }
        do {
            let data = try JSONEncoder().encode(SkillSearchRequest(query: appState.skillSearchQuery))
            let response: SkillSearchResponse = try await APIClient.shared.request(path: "api/skills/search", method: "POST", body: data)
            appState.skillSearchResults = response.catalog
            appState.statusText = "技能搜索完成"
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func installSkill(appState: AppState, name: String, slug: String? = nil, url: String? = nil) async {
        do {
            let data = try JSONEncoder().encode(SkillInstallRequest(name: name, slug: slug, url: url, content: nil))
            var request = URLRequest(url: URL(string: "\(appState.baseURLString)/api/skills/install")!)
            request.httpMethod = "POST"
            request.httpBody = data
            request.setValue("Bearer \(appState.token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("true", forHTTPHeaderField: "X-Confirm-Action")
            let (responseData, _) = try await URLSession.shared.data(for: request)
            let action: ActionResponse = try JSONDecoder().decode(ActionResponse.self, from: responseData)
            appState.statusText = action.message ?? "技能安装完成"
            await refreshSkills(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func removeSkill(appState: AppState, name: String) async {
        do {
            var request = URLRequest(url: URL(string: "\(appState.baseURLString)/api/skills/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)")!)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(appState.token)", forHTTPHeaderField: "Authorization")
            request.setValue("true", forHTTPHeaderField: "X-Confirm-Action")
            let (_, _) = try await URLSession.shared.data(for: request)
            appState.statusText = "技能已移除"
            appState.selectedSkillName = nil
            await refreshSkills(appState: appState)
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func connectChatEvents(appState: AppState) {
        guard let url = URL(string: appState.baseURLString) else { return }
        appState.chatSSE.connect(path: "api/chat/events", token: appState.token, baseURL: url)
    }

    static func connectLogEvents(appState: AppState) {
        guard let url = URL(string: appState.baseURLString) else { return }
        appState.logsSSE.connect(path: "api/logs/events", token: appState.token, baseURL: url)
    }

    static func resolveGate(appState: AppState, requestID: String, threadID: String?, resolution: GateResolutionPayload) async {
        do {
            let data = try JSONEncoder().encode(GateResolveRequest(requestId: requestID, threadId: threadID, resolution: resolution))
            let _: ActionResponse = try await APIClient.shared.request(path: "api/chat/gate/resolve", method: "POST", body: data)
            appState.pendingGate = nil
            appState.statusText = "已提交确认结果"
            if let threadID, let uuid = UUID(uuidString: threadID) {
                await refreshHistory(appState: appState, threadID: uuid)
            }
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func resolveApproval(appState: AppState, requestID: String, threadID: String?, action: String) async {
        do {
            let data = try JSONEncoder().encode(ApprovalResolveRequest(requestId: requestID, threadId: threadID, action: action))
            let _: ActionResponse = try await APIClient.shared.request(path: "api/chat/approval", method: "POST", body: data)
            appState.pendingApproval = nil
            appState.statusText = "已提交审批结果"
            if let threadID, let uuid = UUID(uuidString: threadID) {
                await refreshHistory(appState: appState, threadID: uuid)
            }
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func submitAuthToken(appState: AppState, extensionName: String, token: String, requestID: String?, threadID: String?) async {
        do {
            let data = try JSONEncoder().encode(AuthTokenRequest(extensionName: extensionName, token: token, requestId: requestID, threadId: threadID))
            let _: ActionResponse = try await APIClient.shared.request(path: "api/chat/auth-token", method: "POST", body: data)
            appState.pendingAuth = nil
            appState.statusText = "已提交认证令牌"
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func cancelAuth(appState: AppState, extensionName: String, requestID: String?, threadID: String?) async {
        do {
            let data = try JSONEncoder().encode(AuthCancelRequest(extensionName: extensionName, requestId: requestID, threadId: threadID))
            let _: ActionResponse = try await APIClient.shared.request(path: "api/chat/auth-cancel", method: "POST", body: data)
            appState.pendingAuth = nil
            appState.statusText = "已取消认证"
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    static func sendMessage(appState: AppState) async {
        guard !appState.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let body = SendMessageRequest(
            content: appState.draftMessage,
            threadId: appState.currentThreadID?.uuidString,
            timezone: TimeZone.current.identifier,
            images: appState.draftImages
        )
        do {
            let data = try JSONEncoder().encode(body)
            let _: SendMessageResponse = try await APIClient.shared.request(path: "api/chat/send", method: "POST", body: data)
            appState.streamingText = ""
            appState.statusText = "消息已发送，等待响应"
            appState.draftMessage = ""
            appState.draftImages = []
        } catch {
            appState.statusText = error.localizedDescription
        }
    }
}
