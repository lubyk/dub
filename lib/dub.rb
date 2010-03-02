require 'dub/entities_unescape'
require 'dub/parser'
require 'dub/namespace'
require 'dub/group'
require 'dub/klass'
require 'dub/function'
require 'dub/argument'

module Dub
  def self.parse(filename)
    Dub::Parser.new(filename)
  end
end
