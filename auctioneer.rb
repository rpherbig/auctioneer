require 'discordrb'

ONE = "\u0031\uFE0F\u20E3"
TWO = "\u0032\uFE0F\u20E3"
THREE = "\u0033\uFE0F\u20E3"
BOT_ID = 1167205208909160488
# S, L, K
admins = [85187136659128320, 256665150180818946, 673546923051057183]

bot = Discordrb::Commands::CommandBot.new token: IO.readlines("token.txt", chomp: true).first, prefix: '!'

puts "This bot's invite URL is #{bot.invite_url}."
puts 'Click on it to invite it to your server.'

message_ids = []

#in: "#war-auction"
bot.reaction_add do |reaction_event|
  next unless message_ids.include?(reaction_event.message.id)

  puts reaction_event.message.all_reaction_users()
  # Filter out Bot ID
end

#in: "#war-auction"
bot.reaction_remove do |reaction_event|
  next unless message_ids.include?(reaction_event.message.id)

  puts reaction_event.message.all_reaction_users()
  # Filter out Bot ID
end

bot.command(:start, help_available: false) do |event|
  break unless admins.include?(event.user.id)
  puts 'Received start command'

  bot.send_message(event.channel.id, 'Starting a new auction, please wait to bid!')

  a = bot.send_message(event.channel.id, 'Item A: 12/12 remaining: No bidders')
  a.message.create_reaction(ONE)
  a.message.create_reaction(TWO)
  a.message.create_reaction(THREE)
  message_ids.push a

  b = bot.send_message(event.channel.id, 'Item B: 6/6 remaining: No bidders')
  b.message.create_reaction(ONE)
  b.message.create_reaction(TWO)
  b.message.create_reaction(THREE)
  message_ids.push b

  bot.send_message(event.channel.id, 'The auction is ready, please feel free to bid!')

  nil
end

bot.command(:stop, help_available: false) do |event|
  break unless admins.include?(event.user.id)
  puts 'Received stop command'

  bot.send_message(event.channel.id, 'Stopping the auction!')

  message_ids.clear

  nil
end

bot.command(:exit, help_available: false) do |event|
  break unless admins.include?(event.user.id)
  puts 'Received exit command'

  bot.send_message(event.channel.id, 'Auctioneer is shutting down')
  
  exit
end

at_exit { bot.stop }
bot.run
