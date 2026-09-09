import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var section: AppSection = .home
    @State private var selectedFeatureID: String = "ah_ah_ah"

    private var selectedFeature: FeatureModule {
        FeatureCatalog.all.first(where: { $0.id == selectedFeatureID }) ?? FeatureCatalog.all[0]
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 168, ideal: 188, max: 220)
        } detail: {
            ZStack {
                background
                detailBody
                if viewModel.isDropTargeted { dropOverlay }
                if viewModel.isProcessing { processingOverlay }
            }
            .background {
                PhotoDropTarget(
                    isEnabled: section == .home && !viewModel.isProcessing && !viewModel.liveSession.isRunning
                ) { url in
                    viewModel.handleDrop(url: url)
                } onTargeted: { targeted in
                    viewModel.isDropTargeted = targeted
                }
            }
        }
        .tint(AppTheme.pink)
    }

    private var sidebar: some View {
        List(selection: $section) {
            Section("Eyes Right") {
                ForEach(AppSection.allCases) { item in
                    Label(item.rawValue, systemImage: item.systemImage)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .background(AppTheme.pinkSoft.opacity(0.35))
    }

    @ViewBuilder
    private var detailBody: some View {
        switch section {
        case .home:
            homeDetail
        case .workshop:
            WorkshopView(selectedFeatureID: $selectedFeatureID) { module in
                applyFeature(module)
                section = .home
            }
        case .mine:
            MineView()
        }
    }

    private func applyFeature(_ module: FeatureModule) {
        selectedFeatureID = module.id
        if let mode = module.overlayMode {
            viewModel.overlayMode = mode
        }
        if module.id == "region_live" {
            viewModel.startRegionOverlay()
        }
    }

    private var background: some View {
        ZStack {
            AppTheme.canvas
            LinearGradient(
                colors: [
                    AppTheme.pinkWash.opacity(0.95),
                    AppTheme.pinkSoft.opacity(0.75),
                    AppTheme.canvas,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [AppTheme.pink.opacity(0.12), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var homeDetail: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.panelStroke)
            workspace
                .padding(20)
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.pink, AppTheme.pinkDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .shadow(color: AppTheme.pink.opacity(0.32), radius: 10, y: 4)
                        Image(systemName: "eye.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Eyes Right")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("当前玩法 · \(selectedFeature.title)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                }

                Spacer()

                if selectedFeature.overlayMode != nil {
                    Picker("贴图模式", selection: $viewModel.overlayMode) {
                        ForEach(OverlayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    .disabled(viewModel.isProcessing)
                    .onChange(of: viewModel.overlayMode) { mode in
                        if let match = FeatureCatalog.live.first(where: { $0.overlayMode == mode }) {
                            selectedFeatureID = match.id
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        viewModel.openImage()
                    } label: {
                        Label("选择图片", systemImage: "photo.on.rectangle.angled")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.pink)
                    .disabled(viewModel.isProcessing || viewModel.liveSession.isRunning)
                    .keyboardShortcut("o")

                    if viewModel.liveSession.isRunning {
                        Button {
                            viewModel.liveSession.togglePause()
                        } label: {
                            Label(
                                viewModel.liveSession.isPaused ? "继续" : "暂停",
                                systemImage: viewModel.liveSession.isPaused ? "play.fill" : "pause.fill"
                            )
                            .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.pinkDeep)

                        Button {
                            viewModel.stopRegionOverlay()
                        } label: {
                            Label("结束区域贴眼", systemImage: "stop.fill")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    } else if selectedFeature.id == "region_live" {
                        Button {
                            viewModel.startRegionOverlay()
                        } label: {
                            Label("开始区域贴眼", systemImage: "rectangle.dashed.badge.record")
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.pink)
                        .disabled(viewModel.isProcessing)
                        .keyboardShortcut("r", modifiers: [.command])
                    }

                    Button {
                        viewModel.saveResult()
                    } label: {
                        Label("保存结果", systemImage: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.pink)
                    .disabled(viewModel.resultImage == nil || viewModel.isProcessing || viewModel.liveSession.isRunning)
                    .keyboardShortcut("s")
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 10)

            if viewModel.liveSession.isRunning || !viewModel.liveSession.statusText.isEmpty {
                liveStatusBar
            }
        }
        .background(Color.white.opacity(0.82))
    }

    private var liveStatusBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(viewModel.liveSession.isRunning
                      ? (viewModel.liveSession.isPaused ? Color.orange : AppTheme.pink)
                      : AppTheme.muted)
                .frame(width: 8, height: 8)
            Text(viewModel.liveSession.statusText.isEmpty ? viewModel.statusMessage : viewModel.liveSession.statusText)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            if viewModel.liveSession.isRunning {
                Picker(
                    "帧率",
                    selection: Binding(
                        get: { viewModel.liveSession.fpsPreset },
                        set: { viewModel.liveSession.fpsPreset = $0 }
                    )
                ) {
                    ForEach(LiveFPSPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 110)

                Toggle(
                    "点击穿透",
                    isOn: Binding(
                        get: { viewModel.liveSession.clickThrough },
                        set: { viewModel.liveSession.clickThrough = $0 }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
                .frame(width: 110)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.92))
    }

    private var workspace: some View {
        HStack(spacing: 16) {
            PhotoPanel(
                title: "原图",
                subtitle: "输入",
                image: viewModel.sourceImage,
                emptyTitle: "把照片拖进来",
                emptyHint: "支持 JPG / PNG / HEIC"
            )
            PhotoPanel(
                title: "结果",
                subtitle: "贴眼后",
                image: viewModel.resultImage,
                emptyTitle: "处理完成后显示",
                emptyHint: "自动对齐并覆盖眼睛"
            )
        }
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppTheme.pinkSoft.opacity(0.55))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AppTheme.pink, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 28, weight: .semibold))
                    Text("松开以开始处理")
                        .font(.headline)
                }
                .foregroundStyle(AppTheme.pinkDeep)
            }
            .padding(14)
            .allowsHitTesting(false)
    }

    private var processingOverlay: some View {
        ZStack {
            Color.white.opacity(0.55)
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppTheme.pink)
                Text("正在检测并贴图")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("模型在本地运行，不会上传照片")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(28)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 24, y: 8)
        }
        .ignoresSafeArea()
    }
}

struct WorkshopView: View {
    @Binding var selectedFeatureID: String
    var onSelect: (FeatureModule) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 200), spacing: 14),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("全部玩法")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("选择玩法后回到首页创作；新功能会加在这里")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.muted)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(FeatureCatalog.all) { module in
                        FeatureCard(
                            module: module,
                            selected: selectedFeatureID == module.id
                        ) {
                            if module.isAvailable {
                                onSelect(module)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct FeatureCard: View {
    let module: FeatureModule
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: module.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(module.isAvailable ? AppTheme.pink : AppTheme.muted)
                        .frame(width: 34, height: 34)
                        .background(
                            (module.isAvailable ? AppTheme.pinkSoft : Color.gray.opacity(0.12)),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    Spacer()
                    if let badge = module.badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(module.isAvailable ? Color.white : AppTheme.muted)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                module.isAvailable ? AppTheme.pink : Color.gray.opacity(0.18),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                    }
                }
                Text(module.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(module.isAvailable ? AppTheme.textPrimary : AppTheme.muted)
                Text(module.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? AppTheme.pink : AppTheme.panelStroke, lineWidth: selected ? 1.6 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!module.isAvailable)
        .opacity(module.isAvailable ? 1 : 0.72)
    }
}

struct MineView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [AppTheme.pink, AppTheme.pinkDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 52, height: 52)
                        Image(systemName: "eye.fill")
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Eyes Right")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("本地猫狗贴眼工具")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                GroupBox("关于") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("完全本地处理，不上传云端", systemImage: "lock.fill")
                        Label("版本 0.3.0（Mac）", systemImage: "info.circle")
                        Label(
                            "已上线：\(FeatureCatalog.live.map(\.title).joined(separator: " · "))",
                            systemImage: "sparkles"
                        )
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }

                Text("新功能会先出现在「玩法」分区，再接入首页创作流。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(24)
        }
    }
}

private struct PhotoPanel: View {
    let title: String
    let subtitle: String
    let image: NSImage?
    let emptyTitle: String
    let emptyHint: String

    private let corner: CGFloat = 16
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                if image != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.pink)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 2)

            ZStack {
                RoundedRectangle(cornerRadius: corner + 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.pinkSoft.opacity(0.9),
                                Color.white.opacity(0.65),
                                AppTheme.canvas,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: corner + 4, style: .continuous)
                            .strokeBorder(
                                isHovered ? AppTheme.pink.opacity(0.45) : AppTheme.panelStroke.opacity(0.85),
                                lineWidth: isHovered ? 1.4 : 1
                            )
                    )

                if let image {
                    // 白框贴合照片；悬停轻微放大，像按钮反馈
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .strokeBorder(Color.white, lineWidth: 3.5)
                        )
                        .shadow(
                            color: AppTheme.pink.opacity(isHovered ? 0.28 : 0.18),
                            radius: isHovered ? 22 : 18,
                            y: isHovered ? 10 : 8
                        )
                        .shadow(color: .black.opacity(isHovered ? 0.14 : 0.10), radius: isHovered ? 14 : 10, y: 4)
                        .scaleEffect(isHovered ? 1.035 : 1.0)
                        .padding(14)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                isHovered = hovering
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.pinkSoft)
                                .frame(width: 56, height: 56)
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(AppTheme.pink)
                        }
                        Text(emptyTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(emptyHint)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(
                                AppTheme.pink.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                            )
                            .padding(18)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.22), value: image != nil)
            .onChange(of: image == nil) { _ in
                isHovered = false
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
