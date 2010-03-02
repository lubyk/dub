module Dub
  module MemberExtraction
  end
end
require 'dub/member_extraction'

module Dub
  class Klass
    include MemberExtraction
    attr_reader :name, :xml, :prefix, :constructor, :alias_names, :enums, :parent
    attr_accessor :header

    def initialize(parent, name, xml, prefix = '')
      @parent, @name, @xml, @prefix = parent, name, xml, prefix

      @alias_names = []
      parse_xml
    end

    def bind(generator)
      self.gen = generator.class_generator
    end

    def gen=(generator)
      @gen = generator
      @gen_members = nil
    end

    def to_s
      generator.klass(self)
    end

    def generator
      @gen || (@parent && @parent.class_generator)
    end

    def function_generator
      if generator = self.generator
        generator.function_generator
      else
        nil
      end
    end

    alias gen generator

    def members
      if self.generator
        @gen_members ||= self.generator.members_list(super)
      else
        super
      end
    end

    def <=>(other)
      name <=> other.name
    end

    def [](name)
      name.to_s == @name ? constructor : get_member(name.to_s)
    end

    def class_methods
      []
    end

    def template?
      !@template_params.nil?
    end

    def has_enums?
      !@enums.empty?
    end

    def template_params
      @template_params
    end

    def source
      loc = (@xml/'location').first.attributes
      "#{loc['file'].split('/')[-3..-1].join('/')}:#{loc['line']}"
    end

    def header
      @header ||= (@xml/'location').first.attributes['file'].split('/').last
    end

    def full_type
      @parent ? "#{@parent.full_type}::#{name}" : name
    end

    def lib_name
      "#{prefix}_#{name}"
    end

    def id_name(name = self.name)
      "#{prefix}.#{name}"
    end

    def destructor_name
      "#{name}_destructor"
    end

    def tostring_name
      "#{name}__tostring"
    end

    def constructor
      if defined?(@constructor)
        @constructor
      else
        self.members
        @constructor ||= nil
      end
      @constructor
    end

    private
      def parse_xml
        parse_enums
        parse_members
        parse_template_params
        parse_alias_names
      end

      def parse_enums
        @enums = (@xml/"enumvalue/name").map{|e| e.innerHTML}
      end

      def parse_template_params
        template_params = (@xml/'/templateparamlist/param')
        if !template_params.empty?
          @template_params = template_params.map do |param|
            (param/'/type').innerHTML.gsub(/^\s*(typename|class)\s+/,'')
          end
        end
      end

      def parse_alias_names
        (@xml/'aliases/name').each do |name|
          name = name.innerHTML
          @alias_names << name
          if @parent
            @parent.register_alias(name, self)
          end
        end
      end

      def make_member(name, member, overloaded_index = nil)
        if name == @name
          # keep constructors out of members list
          if @constructor.kind_of?(Group)
            @constructor << super
          elsif @constructor
            list = Dub::Group.new(self)
            list << @constructor
            list << super
            @constructor = list
          else
            @constructor = super
          end
          nil
        else
          super
        end
      end
  end
end