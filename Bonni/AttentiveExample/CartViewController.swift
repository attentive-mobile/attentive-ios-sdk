//
//  CartViewController.swift
//  AttentiveExample
//
//  Created by Adela Gao on 3/5/25.
//

import UIKit
import ATTNSDKFramework

class CartViewController: UIViewController {
    
    private let tableView = UITableView()
    private let viewModel: ProductListViewModel
    private let summaryView = UIView()
    private let subtotalLabel = UILabel()
    private let subtotalValueLabel = UILabel()
    private let taxLabel = UILabel()
    private let taxValueLabel = UILabel()
    private let separator = UIView()
    private let totalLabel = UILabel()
    private let totalValueLabel = UILabel()

    init(viewModel: ProductListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "My Cart"
        view.backgroundColor = .white
        navigationController?.navigationBar.tintColor = .black
        setupSummaryView()
        setupTableView()
        setupCheckoutButton()
        
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(CartTableViewCell.self, forCellReuseIdentifier: "CartCell")
        tableView.rowHeight = 130
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = .black
        tableView.separatorInset = .init(top: 0, left: 8, bottom: 0, right: 0)
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            tableView.bottomAnchor.constraint(equalTo: summaryView.topAnchor, constant: -8)

        ])

        let footerHeight: CGFloat = 80
                let footerView = UIView(frame: CGRect(x: 0,
                                                                                            y: 0,
                                                                                            width: view.bounds.width - 16, // match your tableView width
                                                                                            height: footerHeight))

        let couponButton = UIButton(type: .system)
        couponButton.setTitle("Apply Coupon", for: .normal)
        couponButton.tintColor = .black
        couponButton.titleLabel?.font = UIFont(name: "DegularDisplay-Regular", size: 16)
        couponButton.layer.borderColor = UIColor.black.cgColor
        couponButton.layer.borderWidth = 1
        couponButton.translatesAutoresizingMaskIntoConstraints = false

        footerView.addSubview(couponButton)
        NSLayoutConstraint.activate([
            couponButton.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 16),
                couponButton.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 8),
                couponButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -8),
                couponButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
                couponButton.heightAnchor.constraint(equalToConstant: 56)
        ])
        tableView.tableFooterView = footerView
    }

    private func setupSummaryView() {
        // calculate
        let subtotal = viewModel.cartItems
                .reduce(NSDecimalNumber.zero) { $0.adding($1.product.price.price) }
        let tax = subtotal.multiplying(by: .init(value: 0.05))
        let total = subtotal.adding(tax)

        // style labels
        [subtotalLabel, subtotalValueLabel,
         taxLabel,      taxValueLabel,
         separator,
         totalLabel,    totalValueLabel
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            summaryView.addSubview($0)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let subString = formatter.string(from: subtotal) ?? "0.00"
        let taxString = formatter.string(from: tax)      ?? "0.00"
        let totString = formatter.string(from: total)    ?? "0.00"

        subtotalValueLabel.text = "$\(subString)"
        taxValueLabel.text      = "$\(taxString)"
        totalValueLabel.text    = "$\(totString)"

        subtotalLabel.text = "Subtotal"
        taxLabel.text = "Estimated Tax"
        totalLabel.text = "Total"

        // fonts & colors
        let regularFont = UIFont(name: "DegularDisplay-Regular", size: 16)!
        let mediumFont  = UIFont(name: "DegularDisplay-Medium",  size: 16)!
        subtotalLabel.font = regularFont
        subtotalValueLabel.font = regularFont; subtotalValueLabel.textAlignment = .right
        taxLabel.font      = regularFont
        taxValueLabel.font = regularFont;      taxValueLabel.textAlignment = .right
        totalLabel.font    = mediumFont
        totalValueLabel.font = mediumFont;     totalValueLabel.textAlignment = .right

        separator.backgroundColor = .black

        // add summaryView
        view.addSubview(summaryView)
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            summaryView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            summaryView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            summaryView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            summaryView.heightAnchor.constraint(equalToConstant: 120)
        ])

        // layout inside summaryView
        NSLayoutConstraint.activate([
            // Subtotal row
            subtotalLabel.topAnchor.constraint(equalTo: summaryView.topAnchor, constant: 8),
            subtotalLabel.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor),
            subtotalValueLabel.centerYAnchor.constraint(equalTo: subtotalLabel.centerYAnchor),
            subtotalValueLabel.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor),

            // Tax row
            taxLabel.topAnchor.constraint(equalTo: subtotalLabel.bottomAnchor, constant: 8),
            taxLabel.leadingAnchor.constraint(equalTo: subtotalLabel.leadingAnchor),
            taxValueLabel.centerYAnchor.constraint(equalTo: taxLabel.centerYAnchor),
            taxValueLabel.trailingAnchor.constraint(equalTo: subtotalValueLabel.trailingAnchor),

            // Separator
            separator.topAnchor.constraint(equalTo: taxLabel.bottomAnchor, constant: 8),
            separator.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            // Total row
            totalLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            totalLabel.leadingAnchor.constraint(equalTo: subtotalLabel.leadingAnchor),
            totalValueLabel.centerYAnchor.constraint(equalTo: totalLabel.centerYAnchor),
            totalValueLabel.trailingAnchor.constraint(equalTo: subtotalValueLabel.trailingAnchor),
        ])
    }

    private func setupCheckoutButton() {
        let checkoutButton = UIButton(type: .system)
        checkoutButton.setTitle("CHECK OUT", for: .normal)
        checkoutButton.tintColor = .black

        checkoutButton.titleLabel?.font = UIFont(name: "DegularDisplay-Regular", size: 16)
        checkoutButton.backgroundColor = .black
        checkoutButton.setTitleColor(.white, for: .normal)
        //checkoutButton.layer.cornerRadius = 10
        checkoutButton.addTarget(self, action: #selector(checkoutTapped), for: .touchUpInside)
        
        checkoutButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(checkoutButton)
        
        NSLayoutConstraint.activate([
            checkoutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            checkoutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            checkoutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            checkoutButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    @objc private func checkoutTapped() {
        let addressVC = AddressViewController()
        navigationController?.pushViewController(addressVC, animated: true)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension CartViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.cartItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CartCell", for: indexPath) as? CartTableViewCell else {
            return UITableViewCell()
        }
        
        let cartItem = viewModel.cartItems[indexPath.row]
        cell.configure(with: cartItem.product, quantity: cartItem.quantity)
        cell.delegate = self
        return cell
    }
    
}

// MARK: - CartTableViewCellDelegate
extension CartViewController: CartTableViewCellDelegate {
    func didTapIncrease(in cell: CartTableViewCell) {
        guard let row = tableView.indexPath(for: cell)?.row else { return }
        let product = viewModel.cartItems[row].product
        viewModel.addProductToCart(product)
        tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
    }
    
    func didTapDecrease(in cell: CartTableViewCell) {
        guard let row = tableView.indexPath(for: cell)?.row else { return }
        let product = viewModel.cartItems[row].product
        viewModel.decreaseQuantity(of: product)
        
        // If still present, reload; otherwise delete the row
        if row < viewModel.cartItems.count {
            tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
        } else {
            tableView.deleteRows(at: [IndexPath(row: row, section: 0)], with: .automatic)
        }
    }
}
