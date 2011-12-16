require 'dub/lua/function_gen'
require 'dub/lua/namespace_gen'
require 'dub/lua/class_gen'

module Dub
  module Lua
    def self.function_generator
      @@function_generator ||= Dub::Lua::FunctionGen.new
    end

    def self.class_generator
      @@class_generator ||= Dub::Lua::ClassGen.new
    end

    def self.namespace_generator
      @@namespace_generator ||= Dub::Lua::NamespaceGen.new
    end

    def self.bind(object)
      object.bind(self)
      object
    end
  end # Lua
end # Dub
