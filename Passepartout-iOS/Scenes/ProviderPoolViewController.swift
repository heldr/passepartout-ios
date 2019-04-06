//
//  ProviderPoolViewController.swift
//  Passepartout-iOS
//
//  Created by Davide De Rosa on 6/12/18.
//  Copyright (c) 2019 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of Passepartout.
//
//  Passepartout is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Passepartout is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Passepartout.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import Passepartout_Core

protocol ProviderPoolViewControllerDelegate: class {
    func providerPoolController(_: ProviderPoolViewController, didSelectPool pool: Pool)
}

class ProviderPoolViewController: UIViewController {
    @IBOutlet private weak var tableView: UITableView!

    private var poolsByGroup: [PoolGroup: [Pool]] = [:]

    private var sortedGroups: [PoolGroup] = []

    var currentPoolId: String?
    
    weak var delegate: ProviderPoolViewControllerDelegate?

    func setPools(_ pools: [Pool]) {
        for p in pools {
            poolsByGroup[p.group()] = [p]
        }
        sortedGroups = poolsByGroup.keys.sorted()
    }
    
    // MARK: UIViewController

    override func awakeFromNib() {
        super.awakeFromNib()

        applyDetailTitle(Theme.current)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = L10n.Service.Cells.Provider.Pool.caption
        tableView.reloadData()
        if let ip = selectedIndexPath {
            tableView.scrollToRowAsync(at: ip)
        }
    }
}

// MARK: -

extension ProviderPoolViewController: UITableViewDataSource, UITableViewDelegate {
    private var selectedIndexPath: IndexPath? {
        for entries in poolsByGroup.enumerated() {
            guard let _ = entries.element.value.index(where: { $0.id == currentPoolId }) else {
                continue
            }
            guard let row = sortedGroups.index(of: entries.element.key) else {
                continue
            }
            return IndexPath(row: row, section: 0)
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedGroups.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let group = sortedGroups[indexPath.row]
        let groupPools = poolsByGroup[group]
        let pool = groupPools!.first!
        
        let cell = Cells.setting.dequeue(from: tableView, for: indexPath)
        cell.imageView?.image = pool.logo
        cell.leftText = pool.localizedName
        cell.rightText = pool.areaId?.uppercased()
        cell.applyChecked(pool.id == currentPoolId, Theme.current)
        cell.isTappable = true
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let group = sortedGroups[indexPath.row]
        let groupPools = poolsByGroup[group]
        let pool = groupPools!.first!

        currentPoolId = pool.id
        delegate?.providerPoolController(self, didSelectPool: pool)
    }
}
