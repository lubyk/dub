require 'doxy_generator/function'

module DoxyGenerator
  class Generator
    attr_reader :function
    alias fnt function

    def bind(function)
      if function.kind_of?(Array)
        bind_group(function)
      else
        bind_function(function)
      end
    end

    def bind_function(function, overloaded_index = nil)
      @function = function
<<-END
#{comment}
#{signature(overloaded_index)} {
#{indent(body, 2)}
}
END
    end

    def bind_group(group)
      res = []
      res << function_chooser(group)
      group.each_with_index do |function, i|
        res << bind_function(function, i + 1)
      end
      res.join("\n\n")
    end

    def function_chooser(group)
      @function = group.first
<<-END
#{comment}
#{signature(nil)} {
#{indent(chooser_body(group), 2)}
}
END
    end

    def comment
      "/** #{function.original_signature}\n * #{function.source}\n */"
    end

    def signature(overloaded_index)
      ""
    end

    def body
      ""
    end

    protected
      def indent(str, indent)
        str.gsub(/^/, ' ' * indent)
      end
  end
end # Namespace
