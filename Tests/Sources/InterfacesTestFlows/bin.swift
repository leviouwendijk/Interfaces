import TestFlows

@main
enum InterfacesTestFlowsMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: InterfacesFlowSuite.self
        )
    }
}
