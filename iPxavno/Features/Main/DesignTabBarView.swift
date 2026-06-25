import UIKit

protocol DesignTabBarViewDelegate: AnyObject {
    func designTabBarView(_ tabBarView: DesignTabBarView, didSelect index: Int)
}

struct DesignTabBarItem {
    let title: String
    let normalImageName: String
    let selectedImageName: String
}

final class DesignTabBarView: UIView {
    static let contentHeight: CGFloat = 80

    weak var delegate: DesignTabBarViewDelegate?

    private let selectedColor = UIColor(hex: 0xC8FF35)
    private let normalColor = UIColor(hex: 0x56565C)
    private let stackView = UIStackView()
    private var itemViews: [DesignTabBarItemView] = []

    init(items: [DesignTabBarItem]) {
        super.init(frame: .zero)
        configureView()
        configureItems(items)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func select(index: Int) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        itemViews.enumerated().forEach { itemIndex, itemView in
            itemView.isSelected = itemIndex == index
        }
        CATransaction.commit()
    }

    private func configureView() {
        backgroundColor = UIColor(hex: 0x050506, alpha: 0.94)
        isOpaque = true

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            stackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -5)
        ])
    }

    private func configureItems(_ items: [DesignTabBarItem]) {
        items.enumerated().forEach { index, item in
            let itemView = DesignTabBarItemView(
                item: item,
                selectedColor: selectedColor,
                normalColor: normalColor
            )
            itemView.tag = index
            itemView.addTarget(self, action: #selector(didTapItem(_:)), for: .touchUpInside)
            itemViews.append(itemView)
            stackView.addArrangedSubview(itemView)
        }

        select(index: 0)
    }

    @objc private func didTapItem(_ sender: DesignTabBarItemView) {
        delegate?.designTabBarView(self, didSelect: sender.tag)
    }
}

private final class DesignTabBarItemView: UIControl {
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }

    private let item: DesignTabBarItem
    private let selectedColor: UIColor
    private let normalColor: UIColor
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    init(item: DesignTabBarItem, selectedColor: UIColor, normalColor: UIColor) {
        self.item = item
        self.selectedColor = selectedColor
        self.normalColor = normalColor
        super.init(frame: .zero)
        configureView()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        accessibilityLabel = item.title
        accessibilityTraits = .button

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 13.4, weight: .medium)
        titleLabel.text = item.title
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.86

        addSubview(iconView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            iconView.widthAnchor.constraint(equalToConstant: 31),
            iconView.heightAnchor.constraint(equalToConstant: 31),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 5),
            titleLabel.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    private func updateAppearance() {
        let color = isSelected ? selectedColor : normalColor
        let imageName = isSelected ? item.selectedImageName : item.normalImageName
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        iconView.image = UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal)
        titleLabel.textColor = color

        layer.shadowColor = isSelected ? selectedColor.cgColor : nil
        layer.shadowOpacity = isSelected ? 0.55 : 0
        layer.shadowRadius = isSelected ? 5 : 0
        layer.shadowOffset = .zero
        CATransaction.commit()

        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
