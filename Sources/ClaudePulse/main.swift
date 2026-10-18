import AppKit
import MenuBarKit

if CommandLine.arguments.contains("--hook") {
    let stdin = FileHandle.standardInput.readDataToEndOfFile()
    exit(HookRunner.run(arguments: CommandLine.arguments, stdin: stdin,
                        directory: HookRunner.sessionsDirectory, now: Date(),
                        pid: ClaudeProcess.find(from: getppid())))
}

MainActor.assumeIsolated { runMenuBarApp(AppDelegate()) }
