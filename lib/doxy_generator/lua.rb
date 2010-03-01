require 'doxy_generator/lua/function_gen'
require 'doxy_generator/lua/namespace_gen'
require 'doxy_generator/lua/class_gen'

module DoxyGenerator
  module Lua
    def self.function_generator
      @@function_generator ||= DoxyGenerator::Lua::FunctionGen.new
    end

    def self.class_generator
      @@class_generator ||= DoxyGenerator::Lua::ClassGen.new
    end

    def self.namespace_generator
      @@namespace_generator ||= DoxyGenerator::Lua::NamespaceGen.new
    end

    def self.bind(object)
      if object.kind_of?(DoxyGenerator::Namespace)
        object.bind(namespace_generator)
      #when DoxyGenerator::Class
      #  object.bind(class_generator)
      elsif object.kind_of?(DoxyGenerator::Function) || object.kind_of?(DoxyGenerator::Group)
        object.bind(function_generator)
      elsif object.kind_of?(DoxyGenerator::Namespace)
        object.bind(namespace_generator)
      elsif object.kind_of?(DoxyGenerator::Klass)
        object.bind(class_generator)
      else
        raise "Unsupported type #{object.class} for Lua Generator"
      end
      object
    end
  end # Lua
end # DoxyGenerator
