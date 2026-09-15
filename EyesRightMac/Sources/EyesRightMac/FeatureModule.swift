import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home = "首页"
    case studio = "创作"
    case workshop = "玩法"
    case mine = "我的"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .studio: return "wand.and.stars"
        case .workshop: return "square.grid.2x2.fill"
        case .mine: return "person.fill"
        }
    }
}

enum FeatureStatus {
    case live
    case comingSoon
}

/// 玩法墙分区：创作（按主体）/ 工具 / 规划
enum FeatureCategory: String, CaseIterable, Identifiable, Hashable {
    case create = "创作"
    case tools = "工具"
    case soon = "即将上线"

    var id: String { rawValue }

    var hint: String {
        switch self {
        case .create: return "先选主体，再在首页切换贴图样式"
        case .tools: return "辅助能力，配合创作使用"
        case .soon: return "规划中，敬请期待"
        }
    }
}

struct FeatureModule: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String?
    let status: FeatureStatus
    let category: FeatureCategory
    let systemImage: String
    /// 检测域；贴图样式见 `stickerModes`
    let faceKind: FaceKind
    /// 本模块可选的贴图样式；空表示无静态贴图（如区域实时）
    let stickerModes: [OverlayMode]

    var isAvailable: Bool { status == .live }
    var defaultSticker: OverlayMode? { stickerModes.first }
    var hasStickerPicker: Bool { stickerModes.count >= 2 }
}

enum FeatureCatalog {
    static let all: [FeatureModule] = [
        FeatureModule(
            id: "pet_stickers",
            title: "宠物贴图",
            subtitle: "猫狗正脸 · 啊啊啊 / 加一道光 / 小丑鼻子",
            badge: "热门",
            status: .live,
            category: .create,
            systemImage: "pawprint.fill",
            faceKind: .pet,
            stickerModes: [.ahAhAh, .addLight, .clownNose]
        ),
        FeatureModule(
            id: "anime_eyes",
            title: "动漫贴眼",
            subtitle: "二次元正脸 · 啊啊啊 / 加一道光",
            badge: "新品",
            status: .live,
            category: .create,
            systemImage: "theatermasks.fill",
            faceKind: .anime,
            stickerModes: [.ahAhAh, .addLight]
        ),
        FeatureModule(
            id: "region_live",
            title: "区域贴眼",
            subtitle: "框选屏幕区域，实时叠加当前贴图",
            badge: "电脑端",
            status: .live,
            category: .tools,
            systemImage: "rectangle.dashed.badge.record",
            faceKind: .pet,
            stickerModes: []
        ),
        FeatureModule(
            id: "batch",
            title: "批量贴眼",
            subtitle: "一次处理多张照片",
            badge: "即将上线",
            status: .comingSoon,
            category: .soon,
            systemImage: "square.stack.3d.up.fill",
            faceKind: .pet,
            stickerModes: []
        ),
        FeatureModule(
            id: "video_frame",
            title: "视频抽帧",
            subtitle: "从视频截取正脸再贴图",
            badge: "即将上线",
            status: .comingSoon,
            category: .soon,
            systemImage: "film",
            faceKind: .pet,
            stickerModes: []
        ),
        FeatureModule(
            id: "sticker_shop",
            title: "贴图工坊",
            subtitle: "更多眼罩与素材包",
            badge: "策划中",
            status: .comingSoon,
            category: .soon,
            systemImage: "storefront.fill",
            faceKind: .pet,
            stickerModes: []
        ),
    ]

    static var live: [FeatureModule] { all.filter(\.isAvailable) }

    static func module(id: String) -> FeatureModule? {
        all.first { $0.id == id }
    }

    static func modules(in category: FeatureCategory) -> [FeatureModule] {
        all.filter { $0.category == category }
    }
}
