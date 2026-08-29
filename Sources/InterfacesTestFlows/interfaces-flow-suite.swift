import TestFlows

enum InterfacesFlowSuite: TestFlowRegistry {
    static let title = "Interfaces flow tests"

    static let flows: [TestFlow] = [
        shellFlow,
        ptyFlow,
        gitRepoFlow,
        gitRepoAcquisitionFlow,
        gitManagerDiffFlow,
        gitManagerWorktreeFlow,
        gitManagerIntegrationPlanFlow,
        gitManagerIntegrationExecutionFlow,
        osaScriptFlow,
        weasyPrintFlow,
    ]
}
