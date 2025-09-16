import UIKit

class AddressViewController: UIViewController {

  private let tableView = UITableView(frame: .zero, style: .grouped)
  private var orderTotal: NSDecimalNumber {
    // compute your subtotal here; using a placeholder
    return NSDecimalNumber(string: "123.45")
  }
  private let countryPicker = UIPickerView()
  private let countryList: [String] = Locale.isoRegionCodes
    .compactMap { Locale.current.localizedString(forRegionCode: $0) }
    .sorted()

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Shipping & Billing"
    view.backgroundColor = .white
    setupTableView()

    countryPicker.dataSource = self
    countryPicker.delegate   = self
  }

  private func setupTableView() {
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.dataSource = self
    tableView.delegate   = self

    tableView.register(SummaryTableViewCell.self, forCellReuseIdentifier: SummaryTableViewCell.reuseID)
    tableView.register(TextfieldTableViewCell.self, forCellReuseIdentifier: TextfieldTableViewCell.reuseID)
    tableView.register(ContinueToBillingCell.self, forCellReuseIdentifier: ContinueToBillingCell.reuseID)

    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
    ])
  }
}

// MARK: - UITableViewDataSource

extension AddressViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 5
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
    case 0: return nil
    case 1: return "Contact"
    case 2: return "Delivery"
    case 3: return "Payment"
    default: return nil
    }
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0, 1: return 1
    case 2: return 9
    case 3: return 4
    case 4: return 1
    default: return 0
    }
  }

  func tableView(_ tableView: UITableView,
                 cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {

    case 0:
      guard let cell = tableView.dequeueReusableCell(
        withIdentifier: SummaryTableViewCell.reuseID,
        for: indexPath) as? SummaryTableViewCell
      else {
        fatalError("Could not dequeue SummaryTableViewCell")
      }
      cell.configure(title: "Order Summary",
                     value: "$\(orderTotal.stringValue)")
      return cell

    case 1:
      guard let cell = tableView.dequeueReusableCell(
        withIdentifier: TextfieldTableViewCell.reuseID,
        for: indexPath) as? TextfieldTableViewCell
      else {
        fatalError("Could not dequeue TextfieldTableViewCell")
      }
      cell.configure(placeholder: "Email address")
      return cell

    case 2:
      guard let cell = tableView.dequeueReusableCell(
        withIdentifier: TextfieldTableViewCell.reuseID,
        for: indexPath) as? TextfieldTableViewCell
      else {
        fatalError("Could not dequeue TextfieldTableViewCell")
      }

      let cellTextfield = cell.textField
      if indexPath.row == 0 {
        cell.configure(placeholder: "Country")
        cellTextfield.inputView = countryPicker
      } else {
        let placeholders = [
          "First Name", "Last Name", "Address Line 1", "Address Line 2",
          "City", "State", "Zip Code", "Phone Number"
        ]
        let idx = indexPath.row - 1
        cell.configure(placeholder: placeholders[idx])
        if idx == 7 { cellTextfield.keyboardType = .numberPad }
        if idx == 8 { cellTextfield.keyboardType = .phonePad }
      }

      return cell

    case 3:
      guard let cell = tableView.dequeueReusableCell(
        withIdentifier: TextfieldTableViewCell.reuseID,
        for: indexPath) as? TextfieldTableViewCell
      else {
        fatalError("Could not dequeue TextfieldTableViewCell")
      }

      let textfield = cell.textField
      let paymentPlaceholders = [
        "Card Number", "Name on Card", "Expiration Date", "CVV"
      ]
      cell.configure(placeholder: paymentPlaceholders[indexPath.row])
      if indexPath.row == 0 || indexPath.row == 3 {
        textfield.keyboardType = .numberPad
      }
      return cell

    case 4:
      let cell = tableView.dequeueReusableCell(
        withIdentifier: ContinueToBillingCell.reuseID,
        for: indexPath
      ) as! ContinueToBillingCell
      cell.delegate = self
      return cell

    default:
      fatalError("Unexpected section \(indexPath.section)")
    }
  }
  @objc private func placeOrderTapped() {
    navigationController?.pushViewController(OrderConfirmationViewController(), animated: true)
  }
}

// MARK: - UITableViewDelegate

extension AddressViewController: UITableViewDelegate {
  // (You can implement heightForRowAt or let automaticDimension handle it.)
}

extension AddressViewController: UIPickerViewDataSource, UIPickerViewDelegate {
  func numberOfComponents(in _: UIPickerView) -> Int { 1 }
  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
    countryList.count
  }
  func pickerView(_ pickerView: UIPickerView,
                  titleForRow row: Int,
                  forComponent _: Int) -> String? {
    countryList[row]
  }
  func pickerView(_ pickerView: UIPickerView,
                  didSelectRow row: Int,
                  inComponent _: Int) {
    // Update the country text field when picking
    let ip = IndexPath(row: 0, section: 2)
    if let cell = tableView.cellForRow(at: ip) as? TextfieldTableViewCell {
      cell.textField.text = countryList[row]
    }
  }
}

extension AddressViewController: ContinueToBillingCellDelegate {
  func didTapContinueToBillingCell(_ cell: ContinueToBillingCell) {
    let placeOrderVC = PlaceOrderViewController()
    navigationController?.pushViewController(placeOrderVC, animated: true)
  }

}
