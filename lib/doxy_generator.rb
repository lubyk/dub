require 'doxy_generator/entities_unescape'
require 'doxy_generator/parser'
require 'doxy_generator/lua_generator'

module DoxyGenerator
  def self.parse(filename)
    DoxyGenerator::Parser.new(filename)
  end
end
