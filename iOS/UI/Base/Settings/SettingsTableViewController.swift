//
//  SettingsTableViewController.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 2/27/22.
//

import UIKit
import SafariServices
import LocalAuthentication

class SettingsTableViewController: UITableViewController {

    var items: [SettingItem]

    var requireObservers: [SettingItem] = []

    var observers: [NSObjectProtocol] = []

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    init(items: [SettingItem] = [], style: UITableView.Style = .insetGrouped) {
        self.items = items
        super.init(style: style)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("SETTINGS", comment: "")
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.hidesSearchBarWhenScrolling = false

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.hidesSearchBarWhenScrolling = true
    }
}

// MARK: - Table View Data Source
extension SettingsTableViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items[section].items?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        items[section].title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        items[section].footer
    }

    // MARK: Switch Cell
    func switchCell(for item: SettingItem) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "UITableViewCell.Subtitle")

        cell.detailTextLabel?.text = item.subtitle
        cell.detailTextLabel?.textColor = .secondaryLabel
        let switchView = UISwitch()
        switchView.defaultsKey = item.key ?? ""
        switchView.handleChange { isOn in
            if item.authToDisable ?? false && !isOn {
                let context = LAContext()
                if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                    context.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: NSLocalizedString("AUTH_TO_DISABLE", comment: "")
                    ) { success, _ in
                        if !success {
                            Task { @MainActor in
                                switchView.setOn(true, animated: true)
                                switchView.sendActions(for: .valueChanged)
                            }
                        }
                    }
                }
            } else if item.authToEnable ?? false && isOn {
                let context = LAContext()
                if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                    context.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: NSLocalizedString("AUTH_TO_ENABLE", comment: "")
                    ) { success, _ in
                        if !success {
                            Task { @MainActor in
                                switchView.setOn(false, animated: true)
                                switchView.sendActions(for: .valueChanged)
                            }
                        }
                    }
                }
            }
            if let notification = item.notification {
                NotificationCenter.default.post(name: NSNotification.Name(notification), object: item)
            }
        }
        if let requires = item.requires {
            switchView.isEnabled = UserDefaults.standard.bool(forKey: requires)
            observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(requires), object: nil, queue: nil) { _ in
                switchView.isEnabled = UserDefaults.standard.bool(forKey: requires)
            })
            requireObservers.append(item)
        } else if let requires = item.requiresFalse {
            switchView.isEnabled = !UserDefaults.standard.bool(forKey: requires)
            observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(requires), object: nil, queue: nil) { _ in
                switchView.isEnabled = !UserDefaults.standard.bool(forKey: requires)
            })
            requireObservers.append(item)
        } else {
            switchView.isEnabled = true
        }
        cell.accessoryView = switchView
        cell.selectionStyle = .none

        return cell
    }

    // MARK: Stepper Cell
    func stepperCell(for item: SettingItem) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "UITableViewCell.Value1")

        cell.detailTextLabel?.text = String(UserDefaults.standard.integer(forKey: item.key ?? ""))
        cell.detailTextLabel?.textColor = .secondaryLabel
        let stepperView = UIStepper()
        if let max = item.maximumValue {
            stepperView.maximumValue = max
        }
        if let min = item.minimumValue {
            stepperView.minimumValue = min
        }
        stepperView.defaultsKey = item.key ?? ""
        stepperView.handleChange { _ in
            cell.detailTextLabel?.text = String(UserDefaults.standard.integer(forKey: item.key ?? ""))
            if let notification = item.notification {
                NotificationCenter.default.post(name: NSNotification.Name(notification), object: item)
            }
        }
        if let requires = item.requires {
            stepperView.isEnabled = UserDefaults.standard.bool(forKey: requires)
            NotificationCenter.default.addObserver(forName: NSNotification.Name(requires), object: nil, queue: nil) { _ in
                stepperView.isEnabled = UserDefaults.standard.bool(forKey: requires)
            }
            requireObservers.append(item)
        } else if let requires = item.requiresFalse {
            stepperView.isEnabled = !UserDefaults.standard.bool(forKey: requires)
            NotificationCenter.default.addObserver(forName: NSNotification.Name(requires), object: nil, queue: nil) { _ in
                stepperView.isEnabled = !UserDefaults.standard.bool(forKey: requires)
            }
            requireObservers.append(item)
        } else {
            stepperView.isEnabled = true
        }
        cell.accessoryView = stepperView
        cell.selectionStyle = .none

        return cell
    }

    // swiftlint:disable:next cyclomatic_complexity
    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath,
        settingItem item: SettingItem
    ) -> UITableViewCell {
        let cell: UITableViewCell
        switch item.type {
        case "select":
            cell = UITableViewCell(style: .value1, reuseIdentifier: "UITableViewCell.Value1")
            cell.textLabel?.textColor = .label
            cell.accessoryType = .disclosureIndicator

            if let value = UserDefaults.standard.string(forKey: item.key ?? ""),
               let index = item.values?.firstIndex(of: value) {
                cell.detailTextLabel?.text = item.titles?[index] ?? item.values?[index]
            }

            if let requires = item.requires {
                cell.textLabel?.textColor = UserDefaults.standard.bool(forKey: requires) ? .label : .secondaryLabel
                cell.selectionStyle = UserDefaults.standard.bool(forKey: requires) ? .default : .none
                observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(requires), object: nil, queue: nil) { _ in
                    cell.textLabel?.textColor = UserDefaults.standard.bool(forKey: requires) ? .label : .secondaryLabel
                    cell.selectionStyle = UserDefaults.standard.bool(forKey: requires) ? .default : .none
                })
                requireObservers.append(item)
            } else if let requires = item.requiresFalse {
                cell.textLabel?.textColor = !UserDefaults.standard.bool(forKey: requires) ? .label : .secondaryLabel
                cell.selectionStyle = !UserDefaults.standard.bool(forKey: requires) ? .default : .none
                observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(requires), object: nil, queue: nil) { _ in
                    cell.textLabel?.textColor = !UserDefaults.standard.bool(forKey: requires) ? .label : .secondaryLabel
                    cell.selectionStyle = !UserDefaults.standard.bool(forKey: requires) ? .default : .none
                })
                requireObservers.append(item)
            } else {
                cell.selectionStyle = .default
            }

        case "multi-select", "multi-single-select", "page":
            cell = UITableViewCell(style: .value1, reuseIdentifier: "UITableViewCell.Value1")
            cell.textLabel?.textColor = .label
            cell.accessoryType = .disclosureIndicator

            if item.type == "multi-single-select",
               let value = UserDefaults.standard.stringArray(forKey: item.key ?? "")?.first,
               let index = item.values?.firstIndex(of: value) {
                cell.detailTextLabel?.text = item.titles?[index] ?? item.values?[index]
            }

            if let requires = item.requires {
                cell.textLabel?.textColor = UserDefaults.standard.bool(forKey: requires) ? .label : .secondaryLabel
                cell.selectionStyle = UserDefaults.standard.bool(forKey: requires) ? .default : .none
                observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(requires), object: nil, queue: nil) { _ in
                    cell.textLabel?.textColor = UserDefaults.standard.bool(forKey: requires) ? .label : .secondaryLabel
                    cell.selectionStyle = UserDefaults.standard.bool(forKey: requires) ? .default : .none
                })
                requireObservers.append(item)
            } else if let requires = item.requiresFalse {
                cell.textLabel?.textColor = !UserDefaults.standard.bool(forKey: requires) ? .label : .secondaryLabel
                cell.selectionStyle = !UserDefaults.standard.bool(forKey: requires) ? .default : .none
                observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(requires), object: nil, queue: nil) { _ in
                    cell.textLabel?.textColor = !UserDefaults.standard.bool(forKey: requires) ? .label : .secondaryLabel
                    cell.selectionStyle = !UserDefaults.standard.bool(forKey: requires) ? .default : .none
                })
                requireObservers.append(item)
            } else {
                cell.selectionStyle = .default
            }

        case "switch":
            cell = switchCell(for: item)

        case "stepper":
            cell = stepperCell(for: item)

        case "button", "link":
            cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
            if item.destructive ?? false {
                cell.textLabel?.textColor = .systemRed
            } else {
                cell.textLabel?.textColor = view.tintColor
            }
            cell.accessoryType = .none

        case "text":
            cell = TextInputTableViewCell(reuseIdentifier: "TextInputTableViewCell")
            (cell as? TextInputTableViewCell)?.item = item

        case "segment":
            cell = SegmentTableViewCell(item: item, reuseIdentifier: nil)

        default:
            cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
            cell.textLabel?.textColor = .label
            cell.accessoryType = .none
        }

        cell.textLabel?.text = item.title

        return cell
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let item = items[indexPath.section].items?[indexPath.row] {
            return self.tableView(tableView, cellForRowAt: indexPath, settingItem: item)
        } else {
            return tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        }
    }

    func performAction(for item: SettingItem) {
        if item.type == "select" || item.type == "multi-select" || item.type == "multi-single-select" {
            if let requires = item.requires, !UserDefaults.standard.bool(forKey: requires) { return }
            if let requiresFalse = item.requiresFalse, UserDefaults.standard.bool(forKey: requiresFalse) { return }

            if item.authToOpen ?? false {
                let context = LAContext()
                if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                    context.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: NSLocalizedString("AUTH_TO_OPEN", comment: "")
                    ) { success, _ in
                        if success {
                            Task { @MainActor in
                                self.navigationController?.pushViewController(
                                    SettingSelectViewController(item: item, style: self.tableView.style),
                                    animated: true
                                )
                            }
                        }
                    }
                }
            } else {
                navigationController?.pushViewController(SettingSelectViewController(item: item, style: tableView.style), animated: true)
            }
        } else if item.type == "link" {
            if let url = URL(string: item.key ?? "") {
                if let external = item.external, external {
                    UIApplication.shared.open(url)
                } else {
                    let safariViewController = SFSafariViewController(url: url)
                    present(safariViewController, animated: true)
                }
            }
        } else if item.type == "page", let items = item.items {
            let subPage = SettingsTableViewController(items: items, style: tableView.style)
            subPage.title = item.title
            present(subPage, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let item = items[indexPath.section].items?[indexPath.row] {
            performAction(for: item)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
