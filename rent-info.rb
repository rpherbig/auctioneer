# frozen_string_literal: true

=begin
    Create local file to store subscriber objects, and load it on startup
    Create a method to save the subscriber objects to the local file
    Create a method to load the subscriber objects from the local file
    Create a method to print the subscriber objects to the console
    Create a method to send a PM to all subscribers
    Create a method to add a subscriber
    Create a method to remove a subscriber
    Create a method to check if a user is a subscriber
    Create a method to dedupe the subscriber list
    Create a method to check the calendar day
    Create a method to check if it is time to send the PM
    Create local file to store rent info
    Create a method to load the rent info from the local file and return it
    Ask sheltim where the bot runs and how often it restarts

=end

class RentInfo
    def initialize(bot)
        @bot = bot
        @subscribers = []
    end

    def getTimeUTC()
        time = Time.now.utc
        date_string = time.strftime('%m/%d/%Y')
        time_string = time.strftime('%H:%M:%S')
        return date_string, time_string
    end

    def subscribe(event)
        @subscribers.push(event.user)
        event.user.pm(
            "You have subscribed to rent info! You will receive a PM every day at 13:00 UTC with the current rent info. To unsubscribe, use `!unsubscribe`."
        )
    end

    def unsubscribe(event)
        @subscribers.delete(event.user.id)
        event.user.pm("Successfully unsubscribed from rent info.")
    end

    def printSubs()
        @subscribers.each do |user|
            puts user.display_name
        end
    end
end