# frozen_string_literal: true

require 'discordrb'

ONE = "\u0031\uFE0F\u20E3"
TWO = "\u0032\uFE0F\u20E3"
THREE = "\u0033\uFE0F\u20E3"
REACTIONS = [ONE, TWO, THREE].freeze
REACTION_TO_COUNT = {
  ONE => 1,
  TWO => 2,
  THREE => 3,
}.freeze
BOT_ID = 1167205208909160488
# S, L, K
ADMINS = [85187136659128320, 256665150180818946, 673546923051057183].freeze
AUCTION_ITEMS = {
  '600 species chest' => 8,
  '300 species chest' => 16,
  '100 species chest' => 80,
  '30 alchemy case' => 16,
  '20 coatings' => 16,
  '60 research briefcase' => 16,
  '100 organ chest' => 16,
  '100 evolution chest' => 16,
}.freeze

class Auctioneer
  def initialize
    Discordrb::LOGGER.streams << File.open('log.txt', 'a')
    @message_to_item = {}
    @message_to_reactions = {}

    @bot = Discordrb::Commands::CommandBot.new token: File.readlines('token.txt', chomp: true).first, prefix: '!'
    @bot.command(:start, help_available: false) { |event| start(event) }
    @bot.command(:stop, help_available: false) { |event| stop(event) }
    @bot.command(:exit, help_available: false) { |event| do_exit(event) }
    @bot.reaction_add { |reaction_event| recalculate_reactions('add', reaction_event.message) }
    @bot.reaction_remove { |reaction_event| recalculate_reactions('remove', reaction_event.message) }
    at_exit { @bot.stop }

    log('Bot started up')
  end

  def run
    @bot.run
  end

  def log(text)
    Discordrb::LOGGER.info(text)
  end

  def log_request(name, user)
    log("Received '#{name}' request: #{user.display_name}, #{user.id}")
  end

  def log_reaction(type, message)
    log("Type: '#{type}', Message ID: '#{message.id}', Reactions: #{message.all_reaction_users}")
  end

  def format_auction_item(item_name, remaining_quantity, max_quantity, user_bids)
    bid_string = user_bids.any? ? user_bids.join(', ') : 'No bidders'
    "#{item_name} (#{remaining_quantity}/#{max_quantity} left): #{bid_string}"
  end

  def send(event, text)
    @bot.send_message(event.channel.id, text)
  end

  def recalculate_reactions(type, message)
    return unless @message_to_item.keys.include?(message)

    # reactions?

    log_reaction(type, message)

    reactions = message.all_reaction_users
    @message_to_reactions[message] = reactions
    new_quantity = 0
    user_strings = []
    users_seen = []

    REACTIONS.each do |r|
      users = reactions[r].reject { |u| u.id == BOT_ID }
      users_seen.concat(users)
      users.each do |u|
        count = REACTION_TO_COUNT[r]
        new_quantity += count
        user_string = count == 1 ? u.display_name : "#{u.display_name} x#{count}"
        user_strings.push(user_string)
      end
    end

    item_name = @message_to_item[message]
    max_quantity = AUCTION_ITEMS[item_name]
    remaining = max_quantity - new_quantity
    new_message = format_auction_item(item_name, remaining, max_quantity, user_strings)

    send(message, ":x: Item \"#{item_name}\" has too many bids. :x:") if remaining.negative?

    duplicate_users = users_seen
                      .select { |u| users_seen.count(u) > 1 }
                      .uniq
                      .map(&:mention)
                      .join(' ')
    unless duplicate_users.empty?
      send(message,
           ":x: Attention #{duplicate_users}: you have multiple bids on item \"#{item_name}\". Please only select one reaction per item. :x:")
    end

    overbid_users = @message_to_reactions
                    .flat_map { |_m, all_reactions| REACTIONS.map { |r| all_reactions[r] } }
                    .compact
                    .reject { |user| user.id == BOT_ID }
                    .map(&:mention)
                    .tally
                    .select { |_user, count| count > 3 }
                    .map { |user, _c| user }
                    .join(' ')
    unless overbid_users.empty?
      send(message,
           ":x: Attention #{overbid_users}: you have more than 3 bids across all items. Please only bid on up to 3 items. :x:")
    end

    message.edit(new_message)
  end

  def add_reactions(message)
    REACTIONS.each { |r| message.create_reaction(r) }
  end

  def start(event)
    return unless ADMINS.include?(event.user.id)

    log_request('start', event.user)

    if @message_to_item.any? # reactions?
      send(event, 'Detecting a previously running auction. Stopping it now.')
      @message_to_item.clear
      @message_to_reactions.clear
    end

    time = Time.new
    date_string = time.strftime('%m/%d/%Y')
    send(event, ":tada: Starting a new auction for #{date_string}, please wait a moment! :tada:")

    AUCTION_ITEMS.each do |name, quantity|
      message = format_auction_item(name, quantity, quantity, [])
      e = send(event, message)
      add_reactions(e.message)
      @message_to_item[e.message] = name
      @message_to_reactions[e.message] = {}
    end

    send(event,
         'To claim something, react to its message with the quantity you want. For example, :two: means two of that item.
Note: I am rate limited, so changes may take a minute to show up.
:tada: The auction is ready! :tada:')

    nil
  end

  def stop(event)
    return unless ADMINS.include?(event.user.id)

    log_request('stop', event.user)

    send(event, 'Stopping the auction!')

    @message_to_item.clear
    @message_to_reactions.clear

    nil
  end

  def do_exit(event)
    return unless ADMINS.include?(event.user.id)

    log_request('exit', event.user)

    send(event, 'Auctioneer is shutting down')

    exit
  end
end

a = Auctioneer.new
a.run
