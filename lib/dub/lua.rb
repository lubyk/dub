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
      if object.kind_of?(Dub::Namespace)
        object.bind(namespace_generator)
      #when Dub::Class
      #  object.bind(class_generator)
      elsif object.kind_of?(Dub::Function) || object.kind_of?(Dub::Group)
        object.bind(function_generator)
      elsif object.kind_of?(Dub::Namespace)
        object.bind(namespace_generator)
      elsif object.kind_of?(Dub::Klass)
        object.bind(class_generator)
      else
        raise "Unsupported type #{object.class} for Lua Generator"
      end
      object
    end
  end # Lua
end # Dub
