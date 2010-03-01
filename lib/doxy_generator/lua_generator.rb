require 'doxy_generator/generator'

module DoxyGenerator
  class LuaGenerator < Generator
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
    ]

    def signature(overloaded_index)
      "static int #{method_name(overloaded_index)}(lua_State *L)"
    end

    def method_name(overloaded_index)
      "#{fnt.prefix}_#{fnt.name}#{overloaded_index}"
    end

    def method_call(overloaded_index)
      "return #{method_name(overloaded_index)}(L);"
    end

    def function_call
      call_string = "#{fnt.name}(#{fnt.arguments.map{|arg| arg.in_call_type}.join(', ')});"
      res = []
      if return_type = fnt.return_type
        res << "#{return_type} retval__ = #{call_string}"
        case Argument.type_group(return_type)
        when :number
          res << "lua_pushnumber(L, retval__);"
        when :string
          raise "Not supported yet"
        else
          res << "lua_pushclass<#{return_type}>(L, retval__, \"#{fnt.prefix}.#{return_type}\");"
        end
        res << "return 1;"
      else
        res << call_string
        res << "return 0;"
      end
      res.join("\n")
    end

    # Build code to choose between multiple overloaded functions
    def chooser_body(group)
      res = []
      res << "int type__ = lua_type(L, 1);"
      res << switch(Argument.decision_tree(group))
      res.join("\n")
    end

    def switch(hash_or_function, depth = 1)
      if hash_or_function.kind_of?(Function)
        method_call(hash_or_function.overloaded_index)
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
          else
            res << "#{else_prefix}if (type__ == LUA_TUSERDATA && is_userdata(L, #{depth}, \"#{type}\") {"
          end

          res << indent(switch(sub_group, depth + 1), 2)

          else_prefix = '} else '
        end

        last = default_sub_group.kind_of?(Hash) ? flatten_hash(default_sub_group).last : default_sub_group

        res << "} else {"
        res << "  // use any overloaded methods to raise errors"
        res << indent(method_call(last.overloaded_index), 2)
        res << "}"
        res.join("\n")
      end
    end

    def body
      res = []
      if function.has_default_arguments?
        res << "int top__            = lua_gettop(L);"
      end
      function.arguments.each_with_index do |arg, i|
        res << get_arg(arg, i + 1)
      end
      res << function_call
      res.join("\n")
    end

    def insert_default(arg, stack_pos)
      if arg.has_default?
        "top__ < #{stack_pos} ? #{arg.default} : "
      else
        ''
      end
    end

    # Get argument and verify type
    # // luaL_argcheck could be better to report errors like "expected Mat"
    def get_arg(arg, stack_pos)
      type_def = "#{arg.create_type}#{arg.name}"
      if arg.is_native?
        if arg.is_pointer?
          if arg.type == 'char'
            type_def = "const #{type_def}" unless arg.is_const?
            "%-20s = #{insert_default(arg, stack_pos)}luaL_checkstring(L, %i);" % [type_def, stack_pos]
          else
            # retrieve by using a table accessor
            # TODO: we should have a hint on required sizes !
            "\nDoxyGeneratorArgPointer<#{arg.type}> ptr_#{arg.name};\n" +
            "%-20s = #{insert_default(arg, stack_pos)}ptr_#{arg.name}(L, %i);" % [type_def, stack_pos]
          end
        else
          if FLOAT_TYPES.include?(arg.type)
            "%-20s = #{insert_default(arg, stack_pos)}luaL_checknumber(L, %i);" % [type_def, stack_pos]
          elsif INT_TYPES.include?(arg.type)
            if arg.has_default?
              "%-20s = #{insert_default(arg, stack_pos)}luaL_checkint(L, %i);" % [type_def, stack_pos]
            else
              "%-20s = luaL_checkint   (L, %i);" % [type_def, stack_pos]
            end
          else
            raise "Unsuported type: #{arg.type}"
          end
        end
      else
        "%-20s = luaL_checkudata (L, %i, \"%s\");" % [type_def, stack_pos, "#{arg.function.prefix}.#{arg.type}"]
      end
    end

    private
      def flatten_hash(hash)
        hash.each do |k, v|
          if v.kind_of?(Hash)
            hash[k] = flatten(v)
          end
        end
        hash.to_a.flatten
      end
  end
end # Namespace
