//
//  ViewController.swift
//  EventsApp
//

import UIKit
import AWSAppSync

class EventCell: UITableViewCell {
    @IBOutlet weak var eventNameLabel: UILabel!
    @IBOutlet weak var whenLabel: UILabel!
    @IBOutlet weak var whereLabel: UILabel!
    
    func updateValues(eventName: String, when:String, where: String) {
        eventNameLabel.text = eventName
        whenLabel.text = when
        whereLabel.text = `where`
    }
}

class EventListViewController: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var tableView: UITableView!

    // MARK: - Variables
    
    var appSyncClient: AWSAppSyncClient?
    
    var nextToken: String?
    var fixedLimit: Int = 20 // predefined pagination size
    
    var isListBusy: Bool = false
    var needUpdateList: Bool = false
    var lastOpenedIndex: Int = -1

    var eventList: [ListEventsQuery.Data.ListEvent.Item?] = []
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action:
            #selector(handleRefresh(_:)),
                                 for: .valueChanged)
        
        return refreshControl
    }()
    
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        self.nextToken = nil
        self.loadAllEventsFromServer()
    }
    
    // MARK: - Controller delegates
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // update list only if data source is changed programmatically
        if self.needUpdateList {
            self.needUpdateList = false
            self.nextToken = nil
            self.loadAllEventsFromCache()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.automaticallyAdjustsScrollViewInsets = false
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appSyncClient = appDelegate.appSyncClient
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        self.tableView.addSubview(refreshControl)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .plain, target: self, action: #selector(addTapped))
        
        loadAllEventsFromCache()
    }
    
    // MARK: - Queries
    
    func loadAllEventsFromServer() {
        if isListBusy {
            return
        }
        
        isListBusy = true
        
        self.refreshControl.beginRefreshing()

        let listQuery = ListEventsQuery(limit: self.fixedLimit, nextToken: self.nextToken)
        
        appSyncClient?.fetch(query: listQuery, cachePolicy: .fetchIgnoringCacheData) { (result, error) in
            self.refreshControl.endRefreshing()
            
            if error != nil {
                print(error?.localizedDescription ?? "")
                return
            }
            
            // fresh load check
            if self.nextToken == nil {
                self.eventList.removeAll()
            }
            
            self.eventList.append(contentsOf: result?.data?.listEvents?.items ?? [])
            self.tableView.reloadData()
            self.nextToken = result?.data?.listEvents?.nextToken
            
            // delayed relaising list due to update time for tableview
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                self.isListBusy = false
            })
        }
    }
    
    func loadAllEventsFromCache() {
        if isListBusy {
            return
        }
        
        isListBusy = true
        
        let listQuery = ListEventsQuery(limit: self.fixedLimit, nextToken: self.nextToken)
        
        appSyncClient?.fetch(query: listQuery, cachePolicy: .returnCacheDataAndFetch)  { (result, error) in
            if error != nil {
                print(error?.localizedDescription ?? "")
                return
            }
            
            // fresh load always
            self.eventList.removeAll()
            
            self.eventList.append(contentsOf: result?.data?.listEvents?.items ?? [])
            self.tableView.reloadData()
            self.nextToken = result?.data?.listEvents?.nextToken
            
            // delayed relaising list due to update time for tableview
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                self.isListBusy = false
            })
        }
    }
    
    // MARK: - Click handlers
    
    @objc func addTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AddEventViewController")
        
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Table view delegates

extension EventListViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath) as! EventCell
        let event = eventList[indexPath.row]!
        cell.updateValues(eventName: event.name!, when: event.when!, where: event.where!)
        return cell
    }
    
    // editing check
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // editing action
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            let id = eventList[indexPath.row]?.id
            let deleteEventMutation = DeleteEventMutation(id: id!)
            
            appSyncClient?.perform(mutation: deleteEventMutation, optimisticUpdate: { (transaction) in
                do {
                    // Update our normalized local store immediately for a responsive UI.
                    try transaction?.update(query: ListEventsQuery()) { (data: inout ListEventsQuery.Data) in
                        // remove event from local cache.
                        let newState = data.listEvents?.items?.filter({$0?.id != id })
                        data.listEvents?.items = newState
                    }
                } catch {
                    print("Error removing the object from cache with optimistic response.")
                }
            }) { result, err in
                if let result = result {
                    print("Successful response for delete: \(result)")
                    
                    // refresh updated list in main thread
                    self.eventList.remove(at: indexPath.row)
                    self.tableView.reloadData()
                } else if let error = err {
                    print("Error response for delete: \(error)")
                }
            }
        }
    }
    
    // click handlers
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.lastOpenedIndex = indexPath.row
        
        let event = eventList[self.lastOpenedIndex]!
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "EventDetailsViewController") as! EventDetailsViewController
        controller.event = event.fragments.event
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    // pagination
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if !self.isListBusy && indexPath.row > eventList.count - 2 && self.nextToken?.count ?? 0 > 0 {
            self.loadAllEventsFromServer()
        }
    }
}

