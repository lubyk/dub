require 'dub/entities_unescape'
require 'dub/parser'

module Dub
  def self.parse(filename)
    Dub::Parser.new(filename)
  end
end
