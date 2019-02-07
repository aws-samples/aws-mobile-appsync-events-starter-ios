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
        appSyncClient = appDelegate.appSyncClient!
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

        // Create a GraphQL mutation
        let id = UUID().uuidString
        let addEventMutation = AddEventMutation(name: nameText,
                                                when: whenText,
                                                where: whereText,
                                                description: descriptionText)
        
        appSyncClient?.perform(mutation: addEventMutation, optimisticUpdate: { (transaction) in
            do {
                // Update our normalized local store immediately for a responsive UI.
                try transaction?.update(query: ListEventsQuery()) { (data: inout ListEventsQuery.Data) in
                    data.listEvents?.items?.append(
                        ListEventsQuery.Data.ListEvent.Item(id: id,
                                                            description: descriptionText,
                                                            name: nameText,
                                                            when: whenText,
                                                            where: whereText,
                                                            comments: nil))
                    
                }
            } catch {
                print("Error updating the cache with optimistic response.")
            }
        }) { (result, error) in
            if let error = error as? AWSAppSyncClientError {
                print("Error occurred: \(error.localizedDescription )")
                return
            }
            
            self.navigationController?.popViewController(animated: true)
            
            if let vc = self.navigationController?.viewControllers.last as? EventListViewController {
                vc.needUpdateList = true
            }
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onCancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
