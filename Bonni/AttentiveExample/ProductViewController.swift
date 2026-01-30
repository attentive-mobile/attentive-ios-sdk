//
//  ProductViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/4/25.
//

import ATTNSDKFramework
import UIKit

class ProductViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Constants
    
    private let kPadding: CGFloat = 24
    private let kStackSpacing: CGFloat = 16
    private let kNavColor = UIColor(red: 1, green: 0.773, blue: 0.725, alpha: 1)
    private let kLabelFontSize: CGFloat = 30
    private let kLabelKerning: CGFloat = 1.25
    
    // MARK: - UI Components
    
    private let mainVStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 16  // Will be updated in setupUI()
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var allProductsLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.102, green: 0.118, blue: 0.133, alpha: 1)
        label.font = UIFont(name: "Degular-Medium", size: kLabelFontSize)
        let attributedText = NSMutableAttributedString(string: "All Products", attributes: [
            .kern: kLabelKerning
        ])
        label.attributedText = attributedText
        label.textAlignment = .left
        // Ensure the label expands to fill available width.
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let productsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        // Uncomment for debugging layout:
        // collectionView.backgroundColor = .green
        return collectionView
    }()
    
    private let viewModel = ProductListViewModel()

    private var inboxButton = UIButton()
    private var inboxBadgeView = UIView()
    private var inboxBadgeLabel = UILabel()
    private var inboxObservationTask: Task<Void, Never>?
    
    private var sdk: ATTNSDK? {
        (UIApplication.shared.delegate as? AppDelegate)?.attentiveSdk
    }
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupNavigationBar()
        setupUI()
        setupCollectionView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let sdk else { return }

        inboxObservationTask = Task {
            for await _ in await sdk.inboxStateStream {
                await updateInboxBadge()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        inboxObservationTask?.cancel()
        inboxObservationTask = nil
    }

    // MARK: - Navigation Bar Setup
    
    private func setupNavigationBar() {
        // Configure navigation bar appearance with desired background color.
        if #available(iOS 13.0, *) {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = kNavColor
            navigationController?.navigationBar.standardAppearance = navBarAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
        } else {
            navigationController?.navigationBar.barTintColor = kNavColor
        }
        navigationController?.navigationBar.isTranslucent = false
        
        // Left bar button: settings using "profile" image.
        let settingsImage = UIImage(named: "profile")
        let settingsButtonItem = UIBarButtonItem(image: settingsImage, style: .plain, target: self, action: #selector(settingsButtonTapped))
        settingsButtonItem.tintColor = .black
        navigationItem.leftBarButtonItem = settingsButtonItem
        
        // Right bar buttons: inbox and cart
        let cartImage = UIImage(named: "Shopping cart")
        let cartButtonItem = UIBarButtonItem(image: cartImage, style: .plain, target: self, action: #selector(cartButtonTapped))
        cartButtonItem.tintColor = .black

        let inboxButtonItem = createInboxBarButtonItem()
        navigationItem.rightBarButtonItems = [cartButtonItem, inboxButtonItem]
        
        // Center the logo in the navigation bar.
        let logoImageView = UIImageView(image: UIImage(named: "Union.svg"))
        logoImageView.contentMode = .scaleAspectFit
        navigationItem.titleView = logoImageView
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.addSubview(mainVStackView)
        mainVStackView.spacing = kStackSpacing
        
        // Add arranged subviews.
        mainVStackView.addArrangedSubview(allProductsLabel)
        mainVStackView.addArrangedSubview(productsCollectionView)
        
        // Constrain mainVStackView to the view with 24 points padding on all sides.
        NSLayoutConstraint.activate([
            mainVStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: kPadding),
            mainVStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: kPadding),
            mainVStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -kPadding),
            mainVStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -kPadding)
        ])
    }
    
    // MARK: - Collection View Setup
    
    private func setupCollectionView() {
        productsCollectionView.dataSource = self
        productsCollectionView.delegate = self
        productsCollectionView.register(ProductCollectionViewCell.self, forCellWithReuseIdentifier: "ProductCell")
    }
    
    // MARK: - Inbox Button Setup

    private func createInboxBarButtonItem() -> UIBarButtonItem {
        // Create container view for inbox button and badge (extra height for badge)
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
        containerView.clipsToBounds = false

        // Create inbox button (centered vertically with some top padding for badge)
        inboxButton = UIButton(type: .system)
        inboxButton.frame = CGRect(x: 0, y: 6, width: 30, height: 30)
        inboxButton.setImage(UIImage(systemName: "envelope"), for: .normal)
        inboxButton.tintColor = .black
        inboxButton.addTarget(self, action: #selector(inboxButtonTapped), for: .touchUpInside)
        containerView.addSubview(inboxButton)

        // Create badge view (red circle background) - positioned at top right
        inboxBadgeView = UIView()
        inboxBadgeView.backgroundColor = .systemRed
        inboxBadgeView.layer.cornerRadius = 8
        inboxBadgeView.frame = CGRect(x: 18, y: 0, width: 16, height: 16)
        inboxBadgeView.isHidden = true
        containerView.addSubview(inboxBadgeView)

        // Create badge label (white text)
        inboxBadgeLabel = UILabel()
        inboxBadgeLabel.textColor = .white
        inboxBadgeLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        inboxBadgeLabel.textAlignment = .center
        inboxBadgeLabel.frame = inboxBadgeView.bounds
        inboxBadgeView.addSubview(inboxBadgeLabel)

        return UIBarButtonItem(customView: containerView)
    }

    @MainActor
    private func updateInboxBadge() async {
        let unreadCount = await sdk?.unreadCount ?? 0

        if unreadCount > 0 {
            // Update badge view
            let badgeWidth: CGFloat = unreadCount > 9 ? 20 : 16
            inboxBadgeView.frame = CGRect(x: 36 - badgeWidth, y: 0, width: badgeWidth, height: 16)
            inboxBadgeView.layer.cornerRadius = 8
            inboxBadgeView.backgroundColor = .systemRed
            inboxBadgeView.isHidden = false

            // Update badge label
            inboxBadgeLabel.frame = inboxBadgeView.bounds
            inboxBadgeLabel.text = "\(unreadCount)"
        } else {
            inboxBadgeView.isHidden = true
        }
    }

    // MARK: - Button Actions

    @objc private func inboxButtonTapped() {
        guard let inboxViewController = sdk?.inboxViewController() else {
            return
        }
        navigationController?.pushViewController(inboxViewController, animated: true)
    }

    @objc private func cartButtonTapped() {
        let cartVC = CartViewController(viewModel: viewModel)
        navigationController?.pushViewController(cartVC, animated: true)
    }
    
    @objc private func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    @objc private func checkoutTapped() {
        let addressVC = AddressViewController()
        navigationController?.pushViewController(addressVC, animated: true)
    }
    
    // MARK: - UICollectionView DataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.products.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                                            cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView
            .dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath)
                        as? ProductCollectionViewCell else {
            fatalError("Could not dequeue ProductCollectionViewCell with identifier 'ProductCell'")
        }
        let product = viewModel.products[indexPath.item]
        cell.configure(with: product)
        cell.delegate = self
        return cell
    }

    // MARK: - UICollectionView Delegate Flow Layout
    
    func collectionView(_ collectionView: UICollectionView,
                                            layout collectionViewLayout: UICollectionViewLayout,
                                            sizeForItemAt indexPath: IndexPath) -> CGSize {
            let numberOfColumns: CGFloat = 2
            let interItemSpacing: CGFloat = 10  // This should match your minimumInteritemSpacing
            let totalSpacing = interItemSpacing * (numberOfColumns - 1)

            let cellWidth = (collectionView.frame.width - totalSpacing) / numberOfColumns
            let aspectRatio: CGFloat = 245 / 165  // height = width * (245/165)
            let cellHeight = cellWidth * aspectRatio + 40

            return CGSize(width: cellWidth, height: cellHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
}

// MARK: - ProductCollectionViewCellDelegate

extension ProductViewController: ProductCollectionViewCellDelegate {
    func didTapAddToCartButton(product: ATTNItem) {
        viewModel.addProductToCart(product)
        let addToCartEvent = ATTNAddToCartEvent(items: [product])
        ATTNEventTracker.sharedInstance()?.record(event: addToCartEvent)
        showToast(with: "Add To Cart event sent")
    }
    
    func didTapProductImage(product: ATTNItem) {
        let detailVC = ProductDetailViewController(product: product)
        detailVC.delegate = self
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

extension ProductViewController: ProductDetailViewControllerDelegate {
    func productDetailViewController(_ controller: ProductDetailViewController, didAddToCart product: ATTNItem) {
        viewModel.addProductToCart(product)
        let addToCartEvent = ATTNAddToCartEvent(items: [product])
        ATTNEventTracker.sharedInstance()?.record(event: addToCartEvent)
        showToast(with: "Add To Cart event sent")
    }
}
