//
//  ViewController.swift
//  EventsApp
//

import AWSAppSync
import UIKit

class EventCell: UITableViewCell {
    @IBOutlet var eventNameLabel: UILabel!
    @IBOutlet var whenLabel: UILabel!
    @IBOutlet var whereLabel: UILabel!

    func updateValues(eventName: String?, when: String?, where: String?) {
        eventNameLabel.text = eventName
        whenLabel.text = when
        whereLabel.text = `where`
    }
}

class EventListViewController: UIViewController {
    // MARK: - IBOutlets

    @IBOutlet var tableView: UITableView!

    // MARK: - Variables

    var appSyncClient: AWSAppSyncClient?

    var nextToken: String?
    var fixedLimit: Int = 20 // predefined pagination size

    var isLoadInProgress: Bool = false
    var needUpdateList: Bool = false
    var lastOpenedIndex: Int = -1

    var eventList: [ListEventsQuery.Data.ListEvent.Item?] = []

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self,
                                 action: #selector(handleRefresh(_:)),
                                 for: .valueChanged)

        return refreshControl
    }()

    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        nextToken = nil
        fetchAllEventsUsingCachePolicy(.fetchIgnoringCacheData)
    }

    // MARK: - Controller delegates

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // update list only if data source is changed programmatically
        if needUpdateList {
            needUpdateList = false
            nextToken = nil
            fetchAllEventsUsingCachePolicy(.returnCacheDataAndFetch)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }

        appSyncClient = appDelegate.appSyncClient

        tableView.dataSource = self
        tableView.delegate = self

        tableView.refreshControl = refreshControl

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(addTapped))

        fetchAllEventsUsingCachePolicy(.returnCacheDataAndFetch)
    }

    // MARK: - Queries

    func fetchAllEventsUsingCachePolicy(_ cachePolicy: CachePolicy) {
        if isLoadInProgress {
            return
        }

        isLoadInProgress = true

        refreshControl.beginRefreshing()

        let listQuery = ListEventsQuery(limit: fixedLimit, nextToken: nextToken)

        appSyncClient?.fetch(query: listQuery, cachePolicy: cachePolicy) { result, error in
            self.refreshControl.endRefreshing()

            if let error = error {
                print("Error fetching data: \(error)")
                return
            }

            // Remove existing records if we're either loading from cache, or loading fresh (e.g., from a refresh)
            if self.nextToken == nil, cachePolicy == .returnCacheDataAndFetch {
                self.eventList.removeAll()
            }

            let existingKeys = Set(self.eventList.compactMap { $0?.id })
            let newItems = result?
                .data?
                .listEvents?
                .items?
                .compactMap { $0 }
                .filter { !existingKeys.contains($0.id) }

            self.eventList.append(contentsOf: newItems ?? [])

            self.tableView.reloadData()

            self.nextToken = result?.data?.listEvents?.nextToken

            self.isLoadInProgress = false
        }
    }

    // MARK: - Click handlers

    @objc func addTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let addEventViewController = storyboard.instantiateViewController(withIdentifier: "AddEventViewController")

        navigationController?.pushViewController(addEventViewController, animated: true)
    }
}

// MARK: - Table view delegates

extension EventListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        eventList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath) as? EventCell else {
            return UITableViewCell()
        }

        guard let event = eventList[indexPath.row] else {
            return cell
        }

        cell.updateValues(eventName: event.name, when: event.when, where: event.where)

        return cell
    }

    // editing check
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    // editing action
    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            guard let eventId = eventList[indexPath.row]?.id else {
                return
            }
            let deleteEventMutation = DeleteEventMutation(id: eventId)

            let optimisticUpdate: OptimisticResponseBlock = { transaction in
                do {
                    // Update our normalized local store immediately for a responsive UI.
                    try transaction?.update(query: ListEventsQuery()) { (data: inout ListEventsQuery.Data) in
                        // remove event from local cache.
                        let newState = data.listEvents?.items?.filter { $0?.id != eventId }
                        data.listEvents?.items = newState
                    }
                } catch {
                    print("Error removing the object from cache with optimistic response.")
                }
            }

            appSyncClient?.perform(mutation: deleteEventMutation, optimisticUpdate: optimisticUpdate) { result, error in
                if let result = result {
                    print("Successful response for delete: \(result)")

                    // refresh updated list in main thread
                    self.eventList.remove(at: indexPath.row)
                    self.tableView.reloadData()
                } else if let error = error {
                    print("Error response for delete: \(error)")
                }
            }
        }
    }

    // click handlers
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        lastOpenedIndex = indexPath.row

        guard let event = eventList[indexPath.row] else {
            return
        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let controller = storyboard.instantiateViewController(withIdentifier: "EventDetailsViewController")
            as? EventDetailsViewController else {
                return
        }
        controller.event = event.fragments.event
        navigationController?.pushViewController(controller, animated: true)
    }

    // pagination
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if !isLoadInProgress,
            indexPath.row > eventList.count - 2,
            nextToken?.count ?? 0 > 0 {
            fetchAllEventsUsingCachePolicy(.fetchIgnoringCacheData)
        }
    }
}
