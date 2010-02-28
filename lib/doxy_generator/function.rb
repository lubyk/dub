require 'doxy_generator/argument'
require 'doxy_generator/entities_unescape'

module DoxyGenerator
  class Function
    include DoxyGenerator::EntitiesUnescape
    attr_reader :name, :arguments, :prefix, :overloaded_index, :return_type, :xml

    def initialize(name, xml, prefix = '', overloaded_index = nil)
      @name, @xml, @prefix, @overloaded_index = name, xml, prefix, overloaded_index
      parse_xml
    end

    def source
      loc = (@xml/'location').first.attributes
      "#{loc['file'].split('/')[-3..-1].join('/')}:#{loc['line']}"
    end

    def original_signature
      unescape "#{(@xml/'definition').innerHTML}#{(@xml/'argsstring').innerHTML}"
    end

    def has_default_arguments?
      return @has_defaults if defined?(@has_defaults)
      @has_defaults = !@arguments.detect {|a| a.has_default? }.nil?
    end

    def inspect
      "#<Function #{@prefix}#{@name}(#{@arguments.inspect[1..-2]})>"
    end

    private
      def parse_xml
        @arguments = []
        argstring = (@xml/'param').each do |arg|
          @arguments << Argument.new(self, arg)
        end
        @return_type = (@xml/'/type').innerHTML
        if @return_type
          if @return_type =~ /\s+.*>(.+)</
            @return_type = $1
          elsif @return_type =~ /void$/
            @return_type = nil
          end
        end
      end
  end
end # Namespace
