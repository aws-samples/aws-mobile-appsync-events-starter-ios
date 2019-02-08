//
//  NewPostViewController.swift
//  EventsApp
//

import Foundation
import UIKit
import AWSAppSync

class AddEventViewController: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var nameInput: UITextField!
    @IBOutlet weak var descriptionInput: UITextField!
    @IBOutlet weak var whenInput: UITextField!
    @IBOutlet weak var whereInput: UITextField!

    // MARK: - Variables
    
    var appSyncClient: AWSAppSyncClient?

    // MARK: - Controller delegates
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appSyncClient = appDelegate.appSyncClient
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Click handlers
    
    @IBAction func addNewPost(_ sender: Any) {
        guard let nameText = nameInput.text, !nameText.isEmpty,
            let whenText = whenInput.text, !whenText.isEmpty,
            let whereText = whereInput.text, !whereText.isEmpty,
            let descriptionText = descriptionInput.text, !descriptionText.isEmpty else {
                // Server won't accept empty strings
                let alertController = UIAlertController(title: "Error", message: "Missing values.", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default)
                alertController.addAction(okAction)
                present(alertController, animated: true)

                return
        }

        // We set up a temporary ID so we can reconcile the server-provided ID when `addEventMutation` returns
        let temporaryLocalID = "TEMP-\(UUID().uuidString)"

        let addEventMutation = AddEventMutation(name: nameText,
                                                when: whenText,
                                                where: whereText,
                                                description: descriptionText)

        appSyncClient?.perform(mutation: addEventMutation, optimisticUpdate: { transaction in
            do {
                // Update our normalized local store immediately for a responsive UI.
                try transaction?.update(query: ListEventsQuery()) { (data: inout ListEventsQuery.Data) in
                    let localItem = ListEventsQuery.Data.ListEvent.Item(id: temporaryLocalID,
                                                                        description: descriptionText,
                                                                        name: nameText,
                                                                        when: whenText,
                                                                        where: whereText,
                                                                        comments: nil)

                    data.listEvents?.items?.append(localItem)
                }
            } catch {
                print("Error updating the cache with optimistic response: \(error)")
            }
        }) { (result, error) in
            defer {
                self.navigationController?.popViewController(animated: true)

                if let vc = self.navigationController?.viewControllers.last as? EventListViewController {
                    vc.needUpdateList = true
                }
            }

            guard error == nil else {
                print("Error occurred posting a new item: \(error!.localizedDescription )")
                return
            }

            guard let createEventResponse = result?.data?.createEvent else {
                print("Result unexpectedly nil posting a new item")
                return
            }

            print("New item returned from server and stored in local cache, server-provided id: \(createEventResponse.id)")

            let newItem = ListEventsQuery.Data.ListEvent.Item(
                id: createEventResponse.id,
                description: createEventResponse.description,
                name: createEventResponse.name,
                when: createEventResponse.when,
                where: createEventResponse.where,
                // For simplicity, we're assuming newly-created events have no comments
                comments: nil
            )

            // Update the local cache for the "list events" operation
            _ = self.appSyncClient?.store?.withinReadWriteTransaction() { transaction in
                try transaction.update(query: ListEventsQuery()) { (data: inout ListEventsQuery.Data) in
                    guard data.listEvents != nil else {
                        print("Local cache unexpectedly has no results for ListEventsQuery")
                        return
                    }

                    var updatedItems = data.listEvents?.items?.filter({ $0?.id != temporaryLocalID })
                    updatedItems?.append(newItem)

                    // `data` is an inout variable inside a read/write transaction. Setting `items` here will cause the
                    // local cache to be updated
                    data.listEvents?.items = updatedItems
                }
            }
        }
    }
    
    @IBAction func onCancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
