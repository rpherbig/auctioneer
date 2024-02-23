# frozen_string_literal: true

require 'discordrb'
require './auction'

# S, L, K
ADMINS = [85187136659128320, 256665150180818946, 673546923051057183].freeze

class Auctioneer
  def initialize
    Discordrb::LOGGER.streams << File.open('log.txt', 'a')

    @bot = Discordrb::Commands::CommandBot.new token: File.readlines('token.txt', chomp: true).first, prefix: '!'
    @bot.command(:start, help_available: false) { |event| start(event) }
    @bot.command(:stop, help_available: false) { |event| stop(event) }
    @bot.command(:exit, help_available: false) { |event| do_exit(event) }
    @bot.reaction_add { |reaction_event| recalculate_reactions('add', reaction_event.message) }
    @bot.reaction_remove { |reaction_event| recalculate_reactions('remove', reaction_event.message) }
    at_exit { @bot.stop }

    @auctions = {}

    log('Bot started up')
  end

  def run
    @bot.run
  end

  def log(text)
    Discordrb::LOGGER.info(text)
  end

  def log_from_channel(channel, text)
    log("Channel: #{channel.id}, #{text}")
  end

  def log_request(event, type)
    log_from_channel(event.channel, "Received '#{type}' request from '#{event.user.display_name}' (#{event.user.id})")
  end

  def send(event, text)
    @bot.send_message(event.channel.id, text)
  end

  def recalculate_reactions(type, message)
    auction = @auctions[message.channel.id]
    return if auction.nil?
    return unless auction.auction_message?(message)

    log_from_channel(message.channel, "Message: #{message.id}, Type: '#{type}', Reactions: #{message.all_reaction_users}")

    auction.recalculate_reactions(message)
  end

  def add_reactions(message)
    REACTIONS.each { |r| message.create_reaction(r) }
  end

  def start(event)
    #return unless ADMINS.include?(event.user.id)

    log_request(event, 'start')

    auction = Auction.new(@bot, event.channel.id)
    @auctions[event.channel.id] = auction
    auction.start
  end

  def stop(event)
    #return unless ADMINS.include?(event.user.id)

    log_request(event, 'stop')

    send(event, 'Stopping the auction!')

    @auctions.delete(event.channel.id)

    nil
  end

  def do_exit(event)
    #return unless ADMINS.include?(event.user.id)

    log_request(event, 'exit')

    send(event, 'Auctioneer is shutting down')

    exit
  end
end

a = Auctioneer.new
a.run
