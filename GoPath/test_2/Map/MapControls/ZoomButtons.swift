import UIKit
import SwiftUI

final class ZoomButtons: UIView {
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onLocatePreferredPoint: (() -> Void)?

    private let zoomGroupView = UIView()
    private let dividerView = UIView()
    private let zoomInButton = UIButton(type: .system)
    private let zoomOutButton = UIButton(type: .system)
    private let locateButton = GeolocationButton()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupButtons()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupButtons()
        setupLayout()
    }

    private func setupView() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
    }

    private func setupButtons() {
        configureZoomButton(zoomInButton, title: "+")
        configureZoomButton(zoomOutButton, title: "−")
        configureLocateButton()

        zoomInButton.addTarget(self, action: #selector(handleZoomIn), for: .touchUpInside)
        zoomOutButton.addTarget(self, action: #selector(handleZoomOut), for: .touchUpInside)
        locateButton.addTarget(self, action: #selector(handleLocate), for: .touchUpInside)
    }

    private func configureZoomButton(_ button: UIButton, title: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.96), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 30, weight: .regular)
        button.backgroundColor = .clear
        button.tintColor = UIColor.white.withAlphaComponent(0.96)
        zoomGroupView.addSubview(button)
    }

    private func configureLocateButton() {
        locateButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(locateButton)
        setLocateButtonEnabled(false)
    }

    func setLocateButtonEnabled(_ isEnabled: Bool) {
        locateButton.setAvailable(isEnabled)
    }

    func setLocateButtonActive(_ isActive: Bool) {
        locateButton.setActive(isActive)
    }

    private func setupLayout() {
        
        configureContainer(zoomGroupView, cornerRadius: 20)
        zoomGroupView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(zoomGroupView)

        dividerView.translatesAutoresizingMaskIntoConstraints = false
        dividerView.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        zoomGroupView.addSubview(dividerView)

        NSLayoutConstraint.activate([
            zoomGroupView.topAnchor.constraint(equalTo: topAnchor),
            zoomGroupView.leadingAnchor.constraint(equalTo: leadingAnchor),
            zoomGroupView.trailingAnchor.constraint(equalTo: trailingAnchor),
            zoomGroupView.widthAnchor.constraint(equalToConstant: 56),
            zoomGroupView.heightAnchor.constraint(equalToConstant: 112),

            zoomInButton.topAnchor.constraint(equalTo: zoomGroupView.topAnchor),
            zoomInButton.leadingAnchor.constraint(equalTo: zoomGroupView.leadingAnchor),
            zoomInButton.trailingAnchor.constraint(equalTo: zoomGroupView.trailingAnchor),
            zoomInButton.heightAnchor.constraint(equalToConstant: 56),

            dividerView.topAnchor.constraint(equalTo: zoomInButton.bottomAnchor),
            dividerView.leadingAnchor.constraint(equalTo: zoomGroupView.leadingAnchor, constant: 8),
            dividerView.trailingAnchor.constraint(equalTo: zoomGroupView.trailingAnchor, constant: -8),
            dividerView.heightAnchor.constraint(equalToConstant: 1),

            zoomOutButton.topAnchor.constraint(equalTo: dividerView.bottomAnchor),
            zoomOutButton.leadingAnchor.constraint(equalTo: zoomGroupView.leadingAnchor),
            zoomOutButton.trailingAnchor.constraint(equalTo: zoomGroupView.trailingAnchor),
            zoomOutButton.bottomAnchor.constraint(equalTo: zoomGroupView.bottomAnchor),

            locateButton.topAnchor.constraint(equalTo: zoomGroupView.bottomAnchor, constant: 12),
            locateButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            locateButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            locateButton.widthAnchor.constraint(equalToConstant: 56),
            locateButton.heightAnchor.constraint(equalToConstant: 56),

            locateButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func configureContainer(_ view: UIView, cornerRadius: CGFloat) {
        
        view.backgroundColor = UIColor(red: 0.14, green: 0.17, blue: 0.21, alpha: 0.86)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.09).cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.20
        view.layer.shadowRadius = 14
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.masksToBounds = false
        view.clipsToBounds = false
    }

    @objc private func handleZoomIn() {
        onZoomIn?()
    }

    @objc private func handleZoomOut() {
        onZoomOut?()
    }

    @objc private func handleLocate() {
        onLocatePreferredPoint?()
    }
}



private struct FullScreenPreviewWrapper: View {
    var body: some View {
        NavigatorOnMap()
    }
}

#Preview("Full iPhone Screen") {
    FullScreenPreviewWrapper()
}


