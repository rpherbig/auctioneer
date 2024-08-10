# frozen_string_literal: true

require './cached_message'

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
AUCTION_ITEMS = {
  '600 species chest (1800 w-tads)' => 8,
  '300 species chest (900 w-tads)' => 16,
  '100 species chest (300 w-tads)' => 80,
  '30 alchemy case (300 w-tads)' => 16,
  '20 coatings (200 w-tads)' => 16,
  '60 research briefcase (600 w-tads)' => 16,
  'Blue Species Sequence (500 w-tads)' => 16,
  'Purple Species Sequence (2000 w-tads)' => 16,
  'Orange Species Sequence (6000 w-tads)' => 52,
  '100 organ chest (600 w-tads)' => 16,
  '100 evolution chest (400 w-tads)' => 16,
}.freeze

class Auction
  def initialize(bot, channel_id)
    @message_to_cache = {}
    @bot = bot
    @channel_id = channel_id
  end

  def send(text)
    @bot.send_message(@channel_id, text)
  end

  def format_auction_item(item_name, remaining_quantity, max_quantity, user_bids)
    bid_string = user_bids.any? ? user_bids.join(', ') : 'No bidders'
    "#{item_name} (#{remaining_quantity}/#{max_quantity} left): #{bid_string}"
  end

  def add_reactions(message)
    REACTIONS.each { |r| message.create_reaction(r) }
  end

  def start
    time = Time.new
    date_string = time.strftime('%m/%d/%Y')
    send(":tada: Starting a new auction for #{date_string}, please wait a moment! :tada:")

    AUCTION_ITEMS.each do |name, quantity|
      message = format_auction_item(name, quantity, quantity, [])
      e = send(message)
      add_reactions(e.message)
      @message_to_cache[e.message] = CachedMessage.new(name)
    end

    send('To claim something, react to its message with the quantity you want. For example, :two: means two of that item.
Note: I am rate limited, so changes may take a minute to show up.
:tada: The auction is ready! :tada:')
  end

  def auction_message?(message)
    @message_to_cache.keys.include?(message)
  end

  def recalculate_reactions(message)
    reactions = message.all_reaction_users
    @message_to_cache[message].reactions = reactions
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

    item_name = @message_to_cache[message].item
    max_quantity = AUCTION_ITEMS[item_name]
    remaining = max_quantity - new_quantity
    new_message = format_auction_item(item_name, remaining, max_quantity, user_strings)

    send(":x: Item \"#{item_name}\" has too many bids. :x:") if remaining.negative?

    duplicate_users = users_seen
                      .select { |u| users_seen.count(u) > 1 }
                      .uniq
                      .map(&:mention)
                      .join(' ')
    send(":x: Attention #{duplicate_users}: you have multiple bids on item \"#{item_name}\". Please only select one reaction per item. :x:") unless duplicate_users.empty?

    overbid_users = @message_to_cache # {message -> cachedMessage}
                    .values # [cachedMessage]
                    .map(&:reactions) # [{reaction->[user]}]
                    .map { |hash| hash.transform_keys { |key| REACTION_TO_COUNT[key] } } # [{count->[user]}]
                    .each_with_object(Hash.new(0)) { |hash, accum| hash.each { |count, user_array| user_array.each { |user| accum[user] += count } } } # {user->count}
                    .delete_if { |user, _count| user.id == BOT_ID } # {user->count}
                    .delete_if { |_user, count| count <= 3 } # {user->count}
                    .keys # [user]
                    .map(&:mention) # [user]
                    .join(' ') # string
    send(":x: Attention #{overbid_users}: you have more than 3 bids across all items. Please only bid on up to 3 items. :x:") unless overbid_users.empty?

    message.edit(new_message)
  end
end
