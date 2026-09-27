import SafariServices
import SwiftUI

struct InAppBrowser: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(
        context: Context
    ) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(
            red: 0.31,
            green: 0.52,
            blue: 1.0,
            alpha: 1.0
        )
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(
        _ uiViewController: SFSafariViewController,
        context: Context
    ) {}
}
