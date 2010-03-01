require 'doxy_generator/entities_unescape'
require 'doxy_generator/parser'

module DoxyGenerator
  def self.parse(filename)
    DoxyGenerator::Parser.new(filename)
  end
end
