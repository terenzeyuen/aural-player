
import Cocoa

// Marker protocols

protocol Event {
}

/*
    Contract for all subscribers of events
 */
protocol EventSubscriber {
    
    // Every event subscriber must implement this method to consume an event it is interested in
    func consumeEvent(_ event: Event)
}
