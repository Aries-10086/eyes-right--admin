import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case home = "首页"
    case workshop = "玩法"
    case mine = "我的"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .workshop: return "square.grid.2x2.fill"
        case .mine: return "person.fill"
        }
    }
}

enum FeatureStatus {
    case live
    case comingSoon
}

struct FeatureModule: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String?
    let status: FeatureStatus
    let systemImage: String
    /// 检测域；贴图样式见 `stickerModes`
    let faceKind: FaceKind
    /// 本模块可选的贴图样式；空表示无贴图（如区域实时）
    let stickerModes: [OverlayMode]

    var isAvailable: Bool { status == .live }
    var defaultSticker: OverlayMode? { stickerModes.first }
    var hasStickerPicker: Bool { stickerModes.count >= 2 }
}

enum FeatureCatalog {
    static let all: [FeatureModule] = [
        FeatureModule(
            id: "ah_ah_ah",
            title: "啊啊啊",
            subtitle: "宠物双眼一体眼罩贴图",
            badge: "热门",
            status: .live,
            systemImage: "eye.fill",
            faceKind: .pet,
            stickerModes: [.ahAhAh]
        ),
        FeatureModule(
            id: "add_light",
            title: "加一道光",
            subtitle: "宠物左右眼各贴同一张图",
            badge: "推荐",
            status: .live,
            systemImage: "sparkles",
            faceKind: .pet,
            stickerModes: [.addLight]
        ),
        FeatureModule(
            id: "clown_nose",
            title: "小丑鼻子",
            subtitle: "识别鼻尖贴上红色小丑鼻",
            badge: "新品",
            status: .live,
            systemImage: "nose.fill",
            faceKind: .pet,
            stickerModes: [.clownNose]
        ),
        FeatureModule(
            id: "anime_eyes",
            title: "动漫贴眼",
            subtitle: "二次元脸检测，可选啊啊啊 / 加一道光",
            badge: "新品",
            status: .live,
            systemImage: "theatermasks.fill",
            faceKind: .anime,
            stickerModes: [.ahAhAh, .addLight]
        ),
        FeatureModule(
            id: "region_live",
            title: "区域贴眼",
            subtitle: "框选屏幕区域实时贴图",
            badge: "电脑端",
            status: .live,
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
            systemImage: "square.stack.3d.up.fill",
            faceKind: .pet,
            stickerModes: []
        ),
        FeatureModule(
            id: "video_frame",
            title: "视频抽帧",
            subtitle: "从视频截取正脸再贴眼",
            badge: "即将上线",
            status: .comingSoon,
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
            systemImage: "storefront.fill",
            faceKind: .pet,
            stickerModes: []
        ),
    ]

    static var live: [FeatureModule] { all.filter(\.isAvailable) }

    static func module(id: String) -> FeatureModule? {
        all.first { $0.id == id }
    }

    /// 宠物单贴图玩法：按 OverlayMode 反查
    static func petModule(for mode: OverlayMode) -> FeatureModule? {
        live.first { $0.faceKind == .pet && $0.stickerModes == [mode] }
    }
}
