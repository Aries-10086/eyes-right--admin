import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Divider().overlay(AppTheme.panelStroke)
                workspace
                    .padding(20)
            }

            if viewModel.isDropTargeted {
                dropOverlay
            }

            if viewModel.isProcessing {
                processingOverlay
            }
        }
        .background {
            PhotoDropTarget(isEnabled: !viewModel.isProcessing) { url in
                viewModel.handleDrop(url: url)
            } onTargeted: { targeted in
                viewModel.isDropTargeted = targeted
            }
        }
    }

    private var background: some View {
        ZStack {
            AppTheme.canvas
            RadialGradient(
                colors: [AppTheme.fireflyMint.opacity(0.18), Color.clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 520
            )
            RadialGradient(
                colors: [AppTheme.fireflyPink.opacity(0.12), Color.clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.fireflyMint, AppTheme.fireflyTeal, AppTheme.fireflyPink.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: AppTheme.fireflyMint.opacity(0.38), radius: 10, y: 4)
                    Text("◉◉")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("Eyes Right")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            Picker("贴图模式", selection: $viewModel.overlayMode) {
                ForEach(OverlayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            .disabled(viewModel.isProcessing)

            HStack(spacing: 8) {
                Button {
                    viewModel.openImage()
                } label: {
                    Label("选择图片", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentDeep)
                .disabled(viewModel.isProcessing)
                .keyboardShortcut("o")

                Button {
                    viewModel.saveResult()
                } label: {
                    Label("保存结果", systemImage: "square.and.arrow.down")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accentDeep)
                .disabled(viewModel.resultImage == nil || viewModel.isProcessing)
                .keyboardShortcut("s")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .background(Color.white.opacity(0.82))
    }

    private var workspace: some View {
        HStack(spacing: 18) {
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
            .fill(AppTheme.fireflyMint.opacity(0.15))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AppTheme.accentDeep, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 28, weight: .semibold))
                    Text("松开以开始处理")
                        .font(.headline)
                }
                .foregroundStyle(AppTheme.accentDeep)
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
                    .tint(AppTheme.accentDeep)
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

private struct PhotoPanel: View {
    let title: String
    let subtitle: String
    let image: NSImage?
    let emptyTitle: String
    let emptyHint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
                Spacer()
                if image != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.45, green: 0.86, blue: 0.62))
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(AppTheme.panelStroke, lineWidth: 1)
                    )

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(12)
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "eye")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.fireflyMint, AppTheme.fireflyAmber.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(emptyTitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(emptyHint)
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
