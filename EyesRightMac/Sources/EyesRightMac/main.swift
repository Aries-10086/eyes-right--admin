import AppKit

let args = CommandLine.arguments
if args.count >= 4, args[1] == "--cli" {
    let input = URL(fileURLWithPath: args[2])
    let output = URL(fileURLWithPath: args[3])
    var mode = OverlayMode.ahAhAh
    if args.count >= 5 {
        switch args[4] {
        case "guang", "light", "加一道光":
            mode = .addLight
        default:
            mode = .ahAhAh
        }
    }
    exit(EyesRightMain.runCLI(input: input, output: output, mode: mode))
}

EyesRightMacApp.main()
