require 'doxy_generator/function'

module DoxyGenerator
  class Generator

    def comment(func)
      "/** #{func.original_signature}\n * #{func.source}\n */"
    end

    protected
      def indent(str, indent)
        str.gsub(/^/, ' ' * indent)
      end
  end # Generator
end # DoxyGenerator
