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

class EventListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var appSyncClient: AWSAppSyncClient?
    
    @IBOutlet weak var tableView: UITableView!
    var eventList: [ListEventsQuery.Data.ListEvent.Item?]? = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    func loadAllEvents() {
        appSyncClient?.fetch(query: ListEventsQuery(), cachePolicy: .returnCacheDataAndFetch)  { (result, error) in
            if error != nil {
                print(error?.localizedDescription ?? "")
                return
            }
            self.eventList = result?.data?.listEvents?.items
        }
    }
    
    func loadAllEventsFromCache() {
        
        appSyncClient?.fetch(query: ListEventsQuery(), cachePolicy: .returnCacheDataDontFetch)  { (result, error) in
            if error != nil {
                print(error?.localizedDescription ?? "")
                return
            }
            self.eventList = result?.data?.listEvents?.items
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAllEventsFromCache()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.automaticallyAdjustsScrollViewInsets = false
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appSyncClient = appDelegate.appSyncClient
        
        loadAllEvents()
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .plain, target: self, action: #selector(addTapped))
    }
    
    @objc func addTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "NewPostViewController")
        self.present(controller, animated: true, completion: nil)
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventList?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath) as! EventCell
        let event = eventList![indexPath.row]!
        cell.updateValues(eventName: event.name!, when: event.when!, where: event.where!)
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            let id = eventList![indexPath.row]?.id
            let deleteEventMutation = DeleteEventMutation(id: id!)

            appSyncClient?.perform(mutation: deleteEventMutation, optimisticUpdate: { (transaction) in
                do {
                    // Update our normalized local store immediately for a responsive UI.
                    try transaction?.update(query: ListEventsQuery()) { (data: inout ListEventsQuery.Data) in
                        // remove event from local cache.
                        let newState = data.listEvents?.items?.filter({$0?.id != id })
                        data.listEvents?.items = newState
                    }
                    // load events from cache once the transaction is completed.
                    self.loadAllEventsFromCache()
                } catch {
                    print("Error removing the object from cache with optimistic response.")
                }
            }) { result, err in
                if let result = result {
                    print("Successful response for delete: \(result)")
                } else if let error = err {
                    print("Error response for delete: \(error)")
                }
            }

        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let event = eventList![indexPath.row]!
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "EventDetails") as! EventDetailsViewController
        controller.event = event.fragments.event
        self.navigationController?.pushViewController(controller, animated: true)
        
    }
}

