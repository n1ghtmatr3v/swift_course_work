import UIKit

final class GeolocationButton: UIButton {
    // когда геолокация включена, подсвечиваем кнопку фиолетовым
    private let activeTintColor = UIColor(
        red: 0.6,
        green: 0.50,
        blue: 1,
        alpha: 1
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    func setAvailable(_ isAvailable: Bool) {
        isEnabled = isAvailable
        alpha = isAvailable ? 1.0 : 0.42
        
        if isAvailable == false {
            setActive(false)
        }
    }
    
    func setActive(_ isActive: Bool) {
        tintColor = isActive ? activeTintColor : UIColor.white.withAlphaComponent(0.96)
    }
    
    private func configure() {
        setImage(
            UIImage(systemName: "paperplane.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 19.55, weight: .semibold)),
            for: .normal
        )

        tintColor = UIColor.white.withAlphaComponent(0.96)
        imageView?.contentMode = .scaleAspectFit
        contentHorizontalAlignment = .center
        contentVerticalAlignment = .center
        
        backgroundColor = UIColor(red: 0.14, green: 0.17, blue: 0.21, alpha: 0.86)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.09).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.20
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.masksToBounds = false
        clipsToBounds = false
    }
}
