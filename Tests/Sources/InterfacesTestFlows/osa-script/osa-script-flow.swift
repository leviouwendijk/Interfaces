import Interfaces
import TestFlows

extension InterfacesFlowSuite {
    static var osaScriptFlow: TestFlow {
        TestFlow(
            "osa-script",
            tags: [
                "osascript",
                "process",
                "regression",
            ]
        ) {
            Step("execute AppleScript through Processes") {
                try await runOsascriptProcess(
                    """
                    return 1
                    """
                )
            }

            Step("nonzero osascript exit throws") {
                try await Expect.throwsError(
                    "osascript.nonzero"
                ) {
                    try await runOsascriptProcess(
                        """
                        error "intentional fixture failure"
                        """
                    )
                }
            }
        }
    }
}
