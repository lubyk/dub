require 'dub/argument'
require 'dub/entities_unescape'

module Dub
  class Function
    include Dub::EntitiesUnescape
    attr_reader :arguments, :prefix, :return_value, :xml, :parent
    attr_accessor :gen, :name, :is_constructor, :overloaded_index

    def initialize(parent, name, xml, prefix = '')
      @parent, @name = parent, name
      @xml, @prefix = xml, prefix
      parse_xml
      parse_template_params
    end

    def set_as_constructor
      @return_value = Argument.new(self, (Hpricot::XML("<type>#{name} *</type>")/''))
      @is_constructor = true
    end

    def bind(generator)
      @gen = generator.function_generator
    end

    def to_s
      generator.function(self)
    end

    def generator
      @gen || (@parent && @parent.function_generator)
    end

    def klass
      @parent.kind_of?(Klass) ? @parent : nil
    end

    def member_method?
      !klass.nil?
    end

    def constructor?
      @is_constructor
    end

    def throws?
      @throw ||= (@xml/'exceptions').innerHTML || ''
      @throw = (@throw =~ /throw\s*\(\s*\)/) ? :nothing : :any
      @throw != :nothing
    end

    def custom_body(lang)
      klass ? klass.custom_bind(lang)[self.name] : nil
    end

    def static?
      @is_static
    end

    alias gen generator

    def name=(n)
      @name = n
      if constructor?
        @return_value.type = n
      end
    end

    def call_name
      if klass
        static? ? "#{klass.name}::#{name}" : name
      else
        name
      end
    end

    def id_name
      @parent ? "#{@parent.id_name}.#{name}" : name
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

    def has_array_arguments?
      return @has_array_arguments if defined?(@has_array_arguments)
      @has_array_arguments = !@arguments.detect {|a| a.array_suffix }.nil?
    end

    def has_class_pointer_arguments?
      return @has_class_pointer_arguments if defined?(@has_class_pointer_arguments)
      @has_class_pointer_arguments = !@arguments.detect {|a| !a.is_native? && a.is_pointer? }.nil?
    end

    def has_complex_arguments?
      return @has_complex_arguments if defined?(@has_complex_arguments)
      @has_complex_arguments = !(@arguments + [@return_value]).compact.detect {|a| a.complex? }.nil?
    end

    def vararg?
      @arguments.last && @arguments.last.vararg?
    end

    def arg_is_list(list_position, count_position)
      @arguments[list_position ].is_list       = true
      @arguments[count_position].is_list_count = true
    end

    def template?
      !@template_params.nil?
    end

    def public?
      @xml[:prot] == 'public'
    end

    def template_params
      @template_params
    end

    def inspect
      "#<Function #{@prefix}_#{@name}(#{@arguments.inspect[1..-2]})>"
    end

    def <=>(other)
      name <=> other.name
    end

    # ====== these methods are alias to
    # generator methods on this object

    def method_name(overloaded_index = nil)
      gen.method_name(self, overloaded_index)
    end

    # =================================

    private
      def parse_xml
        @arguments = []

        (@xml/'param').each_with_index do |arg, i|
          @arguments << Argument.new(self, arg, i + 1)
        end

        raw_type = (@xml/'/type').innerHTML

        if raw_type.strip == ''
          # no return type
        else
          arg = Argument.new(self, (@xml/'/type'))
          @return_value = arg unless arg.create_type =~ /void\s*$/
        end

        @is_static = @xml[:static] == 'yes'
      end

      def parse_template_params
        template_params = (@xml/'/templateparamlist/param')
        if !template_params.empty?
          @template_params = template_params.map do |param|
            (param/'/type').innerHTML.gsub(/^\s*(typename|class)\s+/,'')
          end
        end
      end
  end
end # Namespace
