require 'htmlentities'
module Dub
  module EntitiesUnescape
    Decoder = HTMLEntities.new
    def unescape(str)
      Decoder.decode(str)
    end
  end
end