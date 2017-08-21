import Cocoa

class HelpViewController: NSViewController {
    
    private let workspace: NSWorkspace = NSWorkspace.shared()
    
    override func viewDidLoad() {
    }
 
    @IBAction func onlineUserGuideAction(_ sender: Any) {
        workspace.open(AppConstants.onlineUserGuideURL)
    }
    
    @IBAction func pdfUserGuideAction(_ sender: Any) {
        workspace.openFile(AppConstants.pdfUserGuidePath)
    }
}
