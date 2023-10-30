require 'discordrb'
require 'logger'

ONE = "\u0031\uFE0F\u20E3"
TWO = "\u0032\uFE0F\u20E3"
THREE = "\u0033\uFE0F\u20E3"
REACTIONS = [ONE, TWO, THREE]
REACTION_TO_COUNT = {
  ONE => 1,
  TWO => 2,
  THREE => 3,
}
BOT_ID = 1167205208909160488
# S, L, K
ADMINS = [85187136659128320, 256665150180818946, 673546923051057183]
AUCTION_ITEMS = {
  '600 species chest' => 8,
  '300 species chest' => 16,
  '100 species chest' => 80,
  '30 alchemy case' => 16,
  '20 coatings' => 16,
  '60 research briefcase' => 16,
  '100 organ chest' => 16,
  '100 evolution chest' => 16,
}

class Auctioneer
  def initialize
    @message_ids = {}
    @log = Logger.new('log.txt')
    @bot = Discordrb::Commands::CommandBot.new token: IO.readlines("token.txt", chomp: true).first, prefix: '!'
    @log.debug("Bot started up")

    @bot.command(:start, help_available: false) { |event| start(event) }
    @bot.command(:stop, help_available: false) { |event| stop(event) }
    @bot.command(:exit, help_available: false) { |event| do_exit(event) }
    @bot.reaction_add { |reaction_event| recalculate_reactions('add', reaction_event.message) }
    @bot.reaction_remove { |reaction_event| recalculate_reactions('remove', reaction_event.message) }

    at_exit { @bot.stop }
    @bot.run
  end

  def log_request(name, user)
    @log.debug("Received '#{name}' request: #{user.display_name}, #{user.id}")
  end

  def log_reaction(type, message)
    @log.debug("Type: '#{type}', Message ID: '#{message.id}', Reactions: #{message.all_reaction_users()}")
  end

  def format_auction_item(item_name, remaining_quantity, max_quantity, user_bids)
    bid_string = user_bids.length > 0 ? user_bids.join(", ") : "No bidders"
    "#{item_name} (#{remaining_quantity}/#{max_quantity} left): #{bid_string}"
  end

  def recalculate_reactions(type, message)
    return unless @message_ids.keys.include?(message.id)
    log_reaction(type, message)

    reactions = message.all_reaction_users()
    new_quantity = 0
    user_strings = []

    REACTIONS.each do |r|
      users = reactions[r].reject { |u| u.id == BOT_ID }
      users.each do |u|
        count = REACTION_TO_COUNT[r]
        new_quantity += count
        user_string = count == 1 ? u.display_name : "#{u.display_name} x#{count}"
        user_strings.push(user_string)
      end
    end

    item_name = @message_ids[message.id]
    max_quantity = AUCTION_ITEMS[item_name]
    remaining = max_quantity - new_quantity
    new_message = format_auction_item(item_name, remaining, max_quantity, user_strings)

    if remaining < 0
      @bot.send_message(message.channel.id, ":x: Item \"#{item_name}\" has too many bids. I need a human to fix it! :x:")
    end

    message.edit(new_message)
  end

  def add_reactions(message)
    REACTIONS.each { |r| message.create_reaction(r) }
  end

  def start(event)
    return unless ADMINS.include?(event.user.id)
    log_request('start', event.user)

    if @message_ids.length > 0
      @bot.send_message(event.channel.id, "Detecting a previously running auction. Stopping it now.")
      @message_ids.clear
    end

    time = Time.new
    date_string = time.strftime("%m/%d/%Y")
    @bot.send_message(event.channel.id, ":tada: Starting a new auction for #{date_string}, please wait a moment! :tada:")

    AUCTION_ITEMS.each do |name, quantity|
      message = format_auction_item(name, quantity, quantity, [])
      e = @bot.send_message(event.channel.id, message)
      add_reactions(e.message)
      @message_ids[e.message.id] = name
    end

    event << 'To claim something, react to its message with the quantity you want. For example, :two: means two of that item.'
    event << 'Note: I am rate limited, so changes may take a minute to show up.'
    event << ':tada: The auction is ready! :tada:'

    nil
  end

  def stop(event)
    return unless ADMINS.include?(event.user.id)
    log_request('stop', event.user)

    @bot.send_message(event.channel.id, 'Stopping the auction!')

    @message_ids.clear

    nil
  end

  def do_exit(event)
    return unless ADMINS.include?(event.user.id)
    log_request('exit', event.user)

    @bot.send_message(event.channel.id, 'Auctioneer is shutting down')

    exit
  end
end

Auctioneer.new
