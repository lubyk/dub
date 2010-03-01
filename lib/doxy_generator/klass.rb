module DoxyGenerator
  module MemberExtraction
  end
end
require 'doxy_generator/member_extraction'

module DoxyGenerator
  class Klass
    include MemberExtraction
    attr_reader :name, :xml, :prefix, :constructor

    def initialize(parent, name, xml, prefix = '')
      @parent, @name, @xml, @prefix = parent, name, xml, prefix
      parse_xml
    end

    def bind(generator)
      @gen = generator
    end

    def to_s
      generator.klass(self)
    end

    def generator
      @gen || @parent.generator.class_generator
    end

    alias gen generator

    def [](name)
      name.to_s == @name ? constructor : get_member(name.to_s)
    end

    def class_methods
      []
    end

    def source
      loc = (@xml/'location').first.attributes
      "#{loc['file'].split('/')[-3..-1].join('/')}:#{loc['line']}"
    end

    def header
      (@xml/'location').first.attributes['file'].split('/').last
    end

    def lib_name
      "#{prefix}_#{name}"
    end

    def id_name
      "#{prefix}.#{name}"
    end

    def destructor_name
      "#{name}_destructor"
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
        parse_members
      end

      def make_member(name, member, overloaded_index = nil)
        if name =~ /^~/
          # do not build constructor
          return nil
        elsif name == @name
          # keep constructors out of members list
          if @constructor.kind_of?(Group)
            @constructor << super
          elsif @constructor
            list = DoxyGenerator::Group.new(self)
            list << @constructor
            list << super
            @constructor = list
          else
            @constructor = super
          end
          return nil
        end

        super
      end
  end
end