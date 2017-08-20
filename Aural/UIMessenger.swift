import Cocoa

/*
    Messenger for intra-view messages. All messages are dispatched directly from the publisher to the subscriber, via this messenger, synchronously, on the same (calling) thread. For example: When the player starts playing back a new track, it messages the playlist for it to update the playlist selection to match the new playing track.
 
    NOTE - It is ok to do message consumption in a blocking manner because, 1 - in all cases, the messaging is part of a single user interaction, and the main thread needs to perform all chunks of the work immediately, AND 2 - the amount of work to be done is assumed to be quick enough so as not to make the UI unresponsive.
 */
class UIMessenger {
    
    // Keeps track of subscribers. For each message type, stores a list of subscribers
    private static var subscriberRegistry: [MessageType: [MessageSubscriber]] = [MessageType: [MessageSubscriber]]()
    
    // Called by a subscriber who is interested in a certain type of message
    static func subscribe(_ messageType: MessageType, subscriber: MessageSubscriber) {
        
        let subscribers = subscriberRegistry[messageType]
        if (subscribers == nil) {
            subscriberRegistry[messageType] = [MessageSubscriber]()
        }
        
        subscriberRegistry[messageType]?.append(subscriber)
    }
    
    // Called by a publisher to publish a message
    static func publishMessage(_ message: Message) {
        
        let messageType = message.messageType
        let subscribers = subscriberRegistry[messageType]
        
        if (subscribers != nil) {
            for subscriber in subscribers! {
                
                // Notify the subscriber
                subscriber.consumeMessage(message)
            }
        }
    }
}
