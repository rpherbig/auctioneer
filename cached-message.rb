class CachedMessage
  attr_reader :item
  attr_accessor :reactions

  def initialize(item)
      @item = item
      @reactions = {}
  end
end
