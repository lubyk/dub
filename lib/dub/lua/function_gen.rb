require 'dub/generator'
require 'erb'

module Dub
  module Lua
    class FunctionGen < Dub::Generator
      attr_accessor :template_path

      NUMBER_TYPES = [
        'float',
        'double',
        'time_t',
      ]

      INT_TYPES = [
        'int',
        'size_t',
        'unsigned int',
        'uint',
        'uchar',
        'char',
      ]

      BOOL_TYPES = [
        'bool',
      ]

      DEFAULT_CUSTOM_TYPES = [
        [/lua_State /, Proc.new do |type_def, arg, stack_pos|
          if type_def =~ /lua_State\s*\*\s*L/
            ""
          else
            "#{type_def} = L;"
          end
        end]
      ]

      def initialize
        load_erb
        @custom_types = DEFAULT_CUSTOM_TYPES.dup
      end

      def template_path=(template_path)
        @template_path = template_path
        load_erb
      end

      def custom_type(regexp, &block)
        @custom_types << [regexp, block]
      end

      # Produce bindings for a group of overloaded functions
      def group(group)
        @group = group
        if @group.members
          @group_template.result(binding)
        else
          ''
        end
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

      def chooser_body(group = @group)
        if group.first.member_method? && !group.first.constructor?
          delta_depth = 1
        else
          delta_depth = 0
        end
        decision_tree = Argument.decision_tree(group.members)
        res = []
        res << "int type__ = lua_type(L, #{1 + delta_depth});"
        if flatten_hash(decision_tree).include?(nil)
          res << "int top__  = lua_gettop(L);"
        end
        res << switch(decision_tree, delta_depth + 1, true)
        res.join("\n")
      end

      # Create a switch to choose the correct method from argument types (overloaded functions)
      def switch(hash_or_function, depth = 1, start = false)
        if hash_or_function.kind_of?(Function)
          method_call(hash_or_function)
        else
          res = []
          res << "type__ = lua_type(L, #{depth});" unless start
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
              res << "#{else_prefix}if (top__ < #{depth}) {"
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

      # The check_prefix parameter chooses between dubL_check and luaL_check depending
      # on exceptions that can be thrown.
      def body(func, check_prefix)
        res = []
        delta_top = 0
        if func.member_method? && !func.constructor? && !func.static?
          klass = func.parent
          res << "#{klass.name} *self__ = *((#{klass.name}**)#{check_prefix}L_checksdata(L, 1, #{klass.id_name.inspect}));"
          if func.member_method? && func.klass.custom_destructor?
            # protect calls
            if check_prefix == 'dub'
              # we cannot use luaL_error
              res << "if (!self__) throw dub::Exception(\"Using deleted #{klass.id_name} in #{func.name}\");"
            else
              res << "if (!self__) return luaL_error(L, \"Using deleted #{klass.id_name} in #{func.name}\");"
            end
          end
          delta_top = 1
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
            res << indent("if (top__ < #{i+1+delta_top}) {",     if_indent)
            res << indent("  #{call_string(func, i)}", if_indent)
            res << indent("} else {", if_indent)
            if_indent += 2
          end
          res << indent(get_arg(arg, i + 1 + delta_top, check_prefix), if_indent)
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

      def call_string(func, upto_arg = nil)
        upto_arg ||= func.arguments.count
        if upto_arg == 0
          call_string = "#{func.call_name}();"
        else
          call_string = "#{func.call_name}(#{func.arguments[0..(upto_arg-1)].map{|arg| arg.in_call_type}.join(', ')});"
        end

        if func.constructor?
          call_string = "new #{call_string}"
        elsif func.member_method? && !func.static?
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
          if return_value.create_type == 'LuaStackSize '
            return "return retval__;"
          end
          case Argument.type_group(return_value)
          when :number
            res << "lua_pushnumber(L, retval__);"
          when :boolean
            res << "lua_pushboolean(L, retval__);"
          when :string
            res << "lua_pushstring(L, retval__);"
          else
            pushclass = 'lua_pushclass'
            if func.constructor?
              if ctor_with_lua_init?(func)
                res << "// The class inherits from 'LuaCallback', use lua_init instead of pushclass."
                res << "return retval__->lua_init(L, \"#{return_value.id_name}\");"
                return res.join("\n")
              elsif func.klass.custom_destructor?
                # Use special pushclass to set userdata
                pushclass = 'lua_pushclass2'
              end
              prefix = func.klass.prefix
            else
              prefix = func.prefix
            end
            res << "#{pushclass}<#{return_value.type}>(L, retval__, \"#{return_value.id_name}\");"
          end
          res << "return 1;"
        else
          res << "return 0;"
        end
        res.join("\n")
      end

      # Get argument and verify type
      # // luaL_argcheck could be better to report errors like "expected Mat"
      # the check_prefix chooses between 'luaL_check...' and 'dubL_check' methods
      # depending on C++ exceptions raised by the function.
      def get_arg(arg, stack_pos, check_prefix)
        type_def = "#{arg.create_type}#{arg.name}#{arg.array_suffix}"
        if custom_type = @custom_types.detect {|reg,proc| type_def =~ reg}
          custom_type[1].call(type_def, arg, stack_pos)
        elsif arg.is_native?
          if arg.is_pointer?
            if arg.type == 'char'
              type_def = "const #{type_def}" unless arg.is_const?
              "#{type_def} = #{check_prefix}L_checkstring(L, #{stack_pos});"
            else
              # retrieve by using a table accessor
              # TODO: we should have a hint on required sizes !
              "\nDubArgPointer<#{arg.type}> ptr_#{arg.name};\n" +
              "#{type_def} = ptr_#{arg.name}(L, #{stack_pos});"
            end
          else
            if NUMBER_TYPES.include?(arg.type)
              "#{type_def} = #{check_prefix}L_checknumber(L, #{stack_pos});"
            elsif BOOL_TYPES.include?(arg.type)
              "#{type_def} = lua_toboolean(L, #{stack_pos});"
            elsif INT_TYPES.include?(arg.type)
              "#{type_def} = #{check_prefix}L_checkint(L, #{stack_pos});"
            else
              raise "Unsuported type: #{arg.type}"
            end
          end
        else
          "#{type_def} = *((#{arg.create_type}*)#{check_prefix}L_checksdata(L, #{stack_pos}, #{arg.id_name.inspect}));"
        end
      end

      def flatten_hash(hash)
        list = []
        hash.each do |k, v|
          if v.kind_of?(Hash)
            list << [k, flatten_hash(v)]
          else
            list << [k, v]
          end
        end
        list.flatten
      end

      def load_erb
        @function_template = ::ERB.new(File.read(@template_path ||File.join(File.dirname(__FILE__), 'function.cpp.erb')), nil, '%<>-')
        @group_template    = ::ERB.new(File.read(File.join(File.dirname(__FILE__), 'group.cpp.erb')))
      end

      def ctor_with_lua_init?(func)
        # If the class inherits from LuaObject, we need to use
        # s->lua_init(L); instead of pushclass.
        if func.constructor?
          func.klass.ancestors.detect{|a| a =~ /LuaObject/}
        else
          false
        end
      end
    end # FunctionGen
  end # Lua
end # Dub
