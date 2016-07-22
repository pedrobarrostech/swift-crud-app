//
//  EventTableViewController.swift
//  CoreDataCRUD
//  Written by Steven R.
//

import UIKit

/**
    The EventTable ViewController that retrieves and displays events.
*/
class EventTableViewController: UITableViewController, UISearchResultsUpdating {
    
    private var eventList:Array<Event> = []
    private var filteredEventList:Array<Event> = []
    private var selectedEventItem : Event!
    private var resultSearchController:UISearchController!
    private var eventAPI: EventAPI!
    private let eventTableCellIdentifier = "eventItemCell"
    private let showEventItemSegueIdentifier = "showEventItemSegue"
    private let editEventItemSegueIdentifier = "editEventItemSegue"

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initResultSearchController()
    }
    
    override func viewWillAppear(animated: Bool) {
        //Register for notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EventTableViewController.updateEventTableData(_:)), name: "updateEventTableData", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EventTableViewController.setStateLoading(_:)), name: "setStateLoading", object: nil)
        
        self.eventAPI = EventAPI.sharedInstance
        self.eventList = self.eventAPI.getEventsInDateRange()
        self.title = String(format: "Upcoming events (%i)",eventList.count)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Table view data source
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if resultSearchController.active {
            return self.filteredEventList.count
        }
        
        return eventList.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let eventCell =
        tableView.dequeueReusableCellWithIdentifier(eventTableCellIdentifier, forIndexPath: indexPath) as! EventTableViewCell
        
        let eventItem:Event!
        
        if resultSearchController.active {
            eventItem = filteredEventList[indexPath.row]
        } else {
            eventItem = eventList[indexPath.row]
        }
        
        eventCell.eventDateLabel.text = DateFormatter.getStringFromDate(eventItem.date, dateFormat: "dd-MM\nyyyy")
        eventCell.eventTitleLabel.text = eventItem.title
        eventCell.eventLocationLabel.text = "\(eventItem.venue) - \(eventItem.city) - \(eventItem.country)"
        eventCell.eventImageView.image = getEventImage(indexPath)
        
        return eventCell
    }
    
    // MARK: - Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        
        let destination = segue.destinationViewController as? EventItemViewController
        
        if segue.identifier == showEventItemSegueIdentifier {
            /*
                Two options to pass selected Event to destination:
                
                1) Object passing, since eventList contains Event objects:
                destination!.selectedEventItem = eventList[self.tableView.indexPathForSelectedRow!.row] as Event
                
                2) Utilize EventAPI, find Event by Id:
                destination!.selectedEventItem = eventAPI.getById(selectedEventItem.eventId)[0]
            */
            
            let selectedEventItem: Event!
            
            if resultSearchController.active {
                selectedEventItem = filteredEventList[self.tableView.indexPathForSelectedRow!.row] as Event
                resultSearchController.active = false
            } else {
                selectedEventItem = eventList[self.tableView.indexPathForSelectedRow!.row] as Event
            }
            
            destination!.selectedEventItem = eventAPI.getEventById(selectedEventItem.eventId)[0] //option 2
            
            destination!.title = "Edit event"
        } else if segue.identifier == editEventItemSegueIdentifier {
            destination!.title = "Add event"
        }
    }
    
    // MARK: - Table edit mode
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            //Delete item from datastore
            eventAPI.deleteEvent(eventList[indexPath.row])
            //Delete item from tableview datascource
            eventList.removeAtIndex(indexPath.row)
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            self.title = String(format: "Upcoming events (%i)",eventList.count)
        }
    }
    
    // MARK: - Search
    
    /**
        Calls the filter function to filter results by searchbar input
        
        - Parameter searchController: passed Controller to get text from
        - Returns: Void
    */
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        filterEventListContent(searchController.searchBar.text!)
        refreshTableData()
    }
    
    // MARK - Utility functions
    
    /**
        Create a searchbar, bind it to tableview header
    
        - Returns: Void
    */
    private func initResultSearchController() {
        resultSearchController = UISearchController(searchResultsController: nil)
        resultSearchController.searchResultsUpdater = self
        resultSearchController.dimsBackgroundDuringPresentation = false
        resultSearchController.searchBar.sizeToFit()
        
        self.tableView.tableHeaderView = resultSearchController.searchBar
    }
    
    /**
        Create filter predicates to filter events on title, venue, city, data
    
        - Parameter searchTerm: String to search.
        - Returns: Void
    */
    private func filterEventListContent(searchTerm: String) {
        //Clean up filtered list
        filteredEventList.removeAll(keepCapacity: false)
        
        //Create a collection of predicates,
        //search items by: title OR venue OR city
        var predicates = [NSPredicate]()
        predicates.append(NSPredicate(format: "\(EventAttributes.title.rawValue) contains[c] %@", searchTerm.lowercaseString))
        predicates.append(NSPredicate(format: "\(EventAttributes.venue.rawValue) contains[c] %@", searchTerm.lowercaseString))
        predicates.append(NSPredicate(format: "\(EventAttributes.city.rawValue)  contains[c] %@", searchTerm.lowercaseString))

        //TODO add datePredicate to filter on
        
        //Create compound predicate with OR predicates
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        //Filter results with compound predicate by closing over the inline variable
        filteredEventList =  eventList.filter {compoundPredicate.evaluateWithObject($0)}
    }
    
    func updateEventTableData(notification: NSNotification) {
        refreshTableData()
        self.activityIndicator.hidden = true
        self.activityIndicator.stopAnimating()
    }
    
    func setStateLoading(notification: NSNotification) {
        self.activityIndicator.hidden = false
        self.activityIndicator.startAnimating()
    }
    
    /**
        Refresh table data
        
        - Returns: Void
    */
    private func refreshTableData(){
        self.eventList.removeAll(keepCapacity: false)
        self.eventList = self.eventAPI.getEventsInDateRange()
        self.tableView.reloadData()
        self.title = String(format: "Upcoming events (%i)",self.eventList.count)
    }
    
    /**
        Retrieve image from remote or cache.
    
        - Returns: Void
    */
    private func getEventImage(indexPath: NSIndexPath) -> UIImage {
        //TODO
        
        //Check if local image is cached, if not use GCD to download and display it.
        //Use indexPath as reference to cell to be updated.
        
        //For now load from image assets locally.
        return UIImage(named: "eventImageSecond")!
    }
}