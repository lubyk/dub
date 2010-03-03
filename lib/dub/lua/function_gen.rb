require 'dub/generator'
require 'erb'

module Dub
  module Lua
    class FunctionGen < Dub::Generator
      FLOAT_TYPES = [
        'float',
        'double',
        'size_t',
        'unsigned int',
        'uint',
      ]

      INT_TYPES = [
        'int',
        'size_t',
        'unsigned int',
        'uint',
        'bool',
        'uchar'
      ]

      def initialize
        @function_template = ::ERB.new(File.read(File.join(File.dirname(__FILE__), 'function.cpp.erb')))
        @group_template    = ::ERB.new(File.read(File.join(File.dirname(__FILE__), 'group.cpp.erb')))
      end

      # Produce bindings for a group of overloaded functions
      def group(group)
        @group = group
        @group_template.result(binding)
      end

      def function(function)
        @function = function
        @function_template.result(binding)
      end

      def function_generator
        self
      end

      def namespace_generator
        Dub::Lua.namespace_generator
      end

      # Create a switch to choose the correct method from argument types (overloaded functions)
      def switch(hash_or_function, depth = 1)
        if hash_or_function.kind_of?(Function)
          method_call(hash_or_function)
        else
          res = []
          res << "type__ = lua_type(L, #{depth});" unless depth == 1
          else_prefix = ''
          default_sub_group = nil
          hash_or_function.each do |type, sub_group|
            default_sub_group = sub_group
            case type
            when :number
              res << "#{else_prefix}if (type__ == LUA_TNUMBER) {"
            when :string
              res << "#{else_prefix}if (type__ == LUA_TSTRING) {"
            when nil
              res << "#{else_prefix}if (type__ == LUA_TNONE) {"
            else
              res << "#{else_prefix}if (type__ == LUA_TUSERDATA && is_userdata(L, #{depth}, \"#{type}\")) {"
            end

            res << indent(switch(sub_group, depth + 1), 2)

            else_prefix = '} else '
          end

          last = default_sub_group.kind_of?(Hash) ? flatten_hash(default_sub_group).last : default_sub_group

          res << "} else {"
          res << "  // use any to raise errors"
          res << indent(method_call(last), 2)
          res << "}"
          res.join("\n")
        end
      end

      def signature(func, overloaded_index = nil)
        "static int #{method_name(func, overloaded_index)}(lua_State *L)"
      end

      def body(func)
        res = []

        if func.member_method? && !func.constructor?
          klass = func.parent
          res << "#{klass.name} *self__ = *((#{klass.name}**)luaL_checkudata(L, 1, #{klass.id_name.inspect}));"
          res << "lua_remove(L, 1);"
        end

        if func.has_default_arguments?
          res << "int top__ = lua_gettop(L);"
          if return_value = func.return_value
            res << "#{return_value.create_type} retval__;"
          end
        end

        if_indent = 0
        func.arguments.each_with_index do |arg, i|
          if arg.has_default?
            res << indent("if (top__ < #{i+1}) {",     if_indent)
            res << indent("  #{call_string(func, i)}", if_indent)
            res << indent("} else {", if_indent)
            if_indent += 2
          end
          res << indent(get_arg(arg, i + 1), if_indent)
        end
        res << indent(call_string(func, func.arguments.count), if_indent)
        while if_indent > 0
          if_indent -= 2
          res << indent("}", if_indent)
        end

        res << return_value(func)
        res.join("\n")
      end

      def method_name(func, overloaded_index = nil)
        overloaded_index ||= func.overloaded_index
        overloaded_index = '' if overloaded_index == 0
        "#{func.prefix}_#{func.name}#{overloaded_index}"
      end

      def method_call(func)
        "return #{method_name(func)}(L);"
      end

      def call_string(func, upto_arg)
        if upto_arg == 0
          call_string = "#{func.name}();"
        else
          call_string = "#{func.name}(#{func.arguments[0..(upto_arg-1)].map{|arg| arg.in_call_type}.join(', ')});"
        end

        if func.constructor?
          call_string = "new #{call_string}"
        elsif func.member_method?
          call_string = "self__->#{call_string}"
        end


        if return_value = func.return_value
          if func.has_default_arguments?
            "retval__ = #{call_string}"
          else
            "#{return_value.create_type} retval__ = #{call_string}"
          end
        else
          call_string
        end
      end

      def return_value(func)
        res = []
        if return_value = func.return_value
          case Argument.type_group(return_value)
          when :number
            res << "lua_pushnumber(L, retval__);"
          when :string
            raise "Not supported yet"
          else
            if func.constructor?
              prefix = func.klass.prefix
            else
              prefix = func.prefix
            end
            res << "lua_pushclass<#{return_value.type}>(L, retval__, \"#{return_value.id_name}\");"
          end
          res << "return 1;"
        else
          res << "return 0;"
        end
        res.join("\n")
      end

      # Get argument and verify type
      # // luaL_argcheck could be better to report errors like "expected Mat"
      def get_arg(arg, stack_pos)
        type_def = "#{arg.create_type}#{arg.name}#{arg.array_suffix}"
        if arg.is_native?
          if arg.is_pointer?
            if arg.type == 'char'
              type_def = "const #{type_def}" unless arg.is_const?
              "#{type_def} = luaL_checkstring(L, #{stack_pos});"
            else
              # retrieve by using a table accessor
              # TODO: we should have a hint on required sizes !
              "\nDubArgPointer<#{arg.type}> ptr_#{arg.name};\n" +
              "#{type_def} = ptr_#{arg.name}(L, #{stack_pos});"
            end
          else
            if FLOAT_TYPES.include?(arg.type)
              "#{type_def} = luaL_checknumber(L, #{stack_pos});"
            elsif INT_TYPES.include?(arg.type)
              "#{type_def} = luaL_checkint(L, #{stack_pos});"
            else
              raise "Unsuported type: #{arg.type}"
            end
          end
        else
          "#{type_def} = *((#{arg.create_type}*)luaL_checkudata(L, #{stack_pos}, #{arg.id_name.inspect}));"
        end
      end

      def flatten_hash(hash)
        hash.each do |k, v|
          if v.kind_of?(Hash)
            hash[k] = flatten_hash(v)
          end
        end
        hash.to_a.flatten
      end

    end # FunctionGen
  end # Lua
end # Dub
