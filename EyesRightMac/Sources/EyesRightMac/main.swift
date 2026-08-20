import AppKit

let args = CommandLine.arguments
if args.count >= 4, args[1] == "--cli" {
    let input = URL(fileURLWithPath: args[2])
    let output = URL(fileURLWithPath: args[3])
    exit(EyesRightMain.runCLI(input: input, output: output))
}

EyesRightMacApp.main()
