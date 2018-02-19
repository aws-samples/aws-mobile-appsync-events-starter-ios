//
//  EventDetails.swift
//  EventsApp
//

import Foundation
import UIKit
import AWSAppSync

class CommentCell: UITableViewCell {
    @IBOutlet weak var commentContent: UILabel!
}

class EventDetailsViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var eventNameLabel: UILabel!
    @IBOutlet weak var whenLabel: UILabel!
    @IBOutlet weak var whereLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    
    var appSyncClient: AWSAppSyncClient?
    var comments: [Event.Comment.Item?]? = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    var newCommentsSubscriptionWatcher: AWSAppSyncSubscriptionWatcher<NewCommentOnEventSubscription>?
    
    var event: Event?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let event = event {
            eventNameLabel.text = event.name
            whenLabel.text = event.when
            whereLabel.text = event.where
            descriptionLabel.text = event.description
            comments = event.comments?.items
        }
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appSyncClient = appDelegate.appSyncClient
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "New Comment", style: .plain, target: self, action: #selector(addComment))
        
        fetchEventFromCache()
        
        startSubsForEvent()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        print("Cancelling subscritption..")
        newCommentsSubscriptionWatcher?.cancel()
    }

    func fetchEventFromCache() {
        let eventQuery = GetEventQuery(id: self.event!.id)
        appSyncClient?.fetch(query: eventQuery, cachePolicy: .returnCacheDataDontFetch, resultHandler: { (result, error) in
            if let error = error {
                print("Error fetching event \(error.localizedDescription)")
            } else if let result = result {
                if let event = result.data?.getEvent?.fragments.event {
                    self.comments = event.comments?.items
                }
            }
        })
    }
    
    func startSubsForEvent() {
        
        let subscriptionRequest = NewCommentOnEventSubscription(eventId: event!.id)
        do {
            newCommentsSubscriptionWatcher = try appSyncClient?.subscribe(subscription: subscriptionRequest, resultHandler: { (res, transaction, err) in
                guard let _ = self.event?.id else {
                    return
                }
                do {
                    let content = res?.data?.subscribeToEventComments?.content
                    let commentId = res?.data?.subscribeToEventComments?.commentId
                    let createdAt = res?.data?.subscribeToEventComments?.createdAt
                    let eventId = res?.data?.subscribeToEventComments?.eventId
                    
                    // Initialize new comment
                    let newCommentData = CommentOnEventMutation.Data.CommentOnEvent(eventId: eventId!, content: content!, commentId:commentId!, createdAt: createdAt!)
                    let newCommentObject = Event.Comment.Item.init(snapshot: newCommentData.snapshot)
                    
                    // Update list of comments
                    var previousComments = self.event?.comments
                    previousComments?.items?.append(newCommentObject)
                    
                    // Create new event object with updated comments
                    let comments = GetEventQuery.Data.GetEvent.Comment.init(snapshot: previousComments!.snapshot)
                    let eventData = GetEventQuery.Data.GetEvent(id: eventId!,
                                                                description: self.event?.description,
                                                                name: self.event?.name,
                                                                when: self.event?.when,
                                                                where: self.event?.where,
                                                                comments: comments)
                    
                    // Write new event object to the store
                    try transaction?.write(object: eventData, withKey: eventId!)
                    
                    // reload data from cache
                    self.fetchEventFromCache()
                } catch {
                    print("error occurred while updating store. \(error)")
                }
            })
        }
        catch {
            print("Failed subscribing to new comments on this post. \(error)")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentCell
        cell.commentContent.text = comments![indexPath.row]!.content
        return cell
    }
    
    @objc func addComment() {
        let alertController = UIAlertController(title: "New Comment", message: "Type in your thoughts.", preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: "Enter", style: .default) { (_) in
            let comment = alertController.textFields?[0].text
            let mutation = CommentOnEventMutation(eventId: self.event!.id, content: comment!, createdAt: Date().description)
            
            self.appSyncClient?.perform(mutation: mutation)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        alertController.addTextField { (textField) in
            textField.placeholder = "Type the comment here.."
        }
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
}
