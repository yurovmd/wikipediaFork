import UIKit

/// A `UIImageView` embedded within a `UIView` to allow easier styling
class RoundedImageView: SetupView {

	// MARK: - Properties

	let imageView = UIImageView()

	var insets: NSDirectionalEdgeInsets = .zero {
		didSet {
			imageViewLeadingAnchor?.constant = insets.leading
			imageViewTrailingAnchor?.constant = insets.trailing
			imageViewTopAnchor?.constant = insets.top
			imageViewBottomAnchor?.constant = insets.bottom
		}
	}

	fileprivate var imageViewLeadingAnchor: NSLayoutConstraint?
	fileprivate var imageViewTrailingAnchor: NSLayoutConstraint?
	fileprivate var imageViewTopAnchor: NSLayoutConstraint?
	fileprivate var imageViewBottomAnchor: NSLayoutConstraint?

	// MARK: - Lifecycle

	override func layoutSubviews() {
		super.layoutSubviews()
		layer.cornerRadius = self.bounds.height / 2
	}

	// MARK: - Setup

	override func setup() {
		layer.masksToBounds = true
		imageView.translatesAutoresizingMaskIntoConstraints = false
		
		addSubview(imageView)

		imageViewLeadingAnchor = imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.leading)
		imageViewTrailingAnchor = imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: insets.trailing)
		imageViewTopAnchor = imageView.topAnchor.constraint(equalTo: topAnchor, constant: insets.top)
		imageViewBottomAnchor = imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom)

		NSLayoutConstraint.activate(
			[imageViewLeadingAnchor, imageViewTrailingAnchor, imageViewTopAnchor, imageViewBottomAnchor].compactMap { $0 }
		)

		setNeedsLayout()
		layoutIfNeeded()
	}

}
