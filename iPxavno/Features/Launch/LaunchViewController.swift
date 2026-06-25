import UIKit

final class LaunchViewController: BaseViewController {
    private let markView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Color.ink
        configureView()
    }

    private func configureView() {
        markView.translatesAutoresizingMaskIntoConstraints = false
        markView.backgroundColor = AppTheme.Color.accent
        markView.layer.cornerRadius = 18

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "ArcLab"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        titleLabel.textAlignment = .center

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Creative media studio"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        subtitleLabel.font = AppTheme.Font.body
        subtitleLabel.textAlignment = .center

        view.addSubview(markView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            markView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            markView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -54),
            markView.widthAnchor.constraint(equalToConstant: 72),
            markView.heightAnchor.constraint(equalTo: markView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: markView.bottomAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.Metric.screenInset),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.Metric.screenInset),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])
    }
}
