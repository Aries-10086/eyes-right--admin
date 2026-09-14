import AppKit

let args = CommandLine.arguments
if args.count >= 4, args[1] == "--cli" {
    let input = URL(fileURLWithPath: args[2])
    let output = URL(fileURLWithPath: args[3])
    var mode = OverlayMode.ahAhAh
    var faceKind = FaceKind.pet
    if args.count >= 5 {
        switch args[4] {
        case "guang", "light", "加一道光":
            mode = .addLight
        case "clown", "nose", "小丑鼻子":
            mode = .clownNose
        case "anime", "anime-ah", "动漫贴眼", "动漫啊啊啊":
            faceKind = .anime
            mode = .ahAhAh
        case "anime-guang", "anime-light", "动漫加一道光":
            faceKind = .anime
            mode = .addLight
        default:
            mode = .ahAhAh
        }
    }
    exit(EyesRightMain.runCLI(input: input, output: output, mode: mode, faceKind: faceKind))
}

EyesRightMacApp.main()
