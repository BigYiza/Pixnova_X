import UIKit

final class LaunchViewController: BaseViewController {
    private let AppIcon = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureView()
    }

    private func configureView() {
        
        AppIcon.image = UIImage(named: "icon")

        view.addSubview(AppIcon)

        NSLayoutConstraint.activate([
            AppIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            AppIcon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            AppIcon.widthAnchor.constraint(equalToConstant: 120),
            AppIcon.heightAnchor.constraint(equalTo: AppIcon.widthAnchor),
        ])
    }
}
