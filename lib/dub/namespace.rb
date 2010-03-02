require 'dub/member_extraction'

module Dub

  class Namespace
    include MemberExtraction

    attr_reader :name
    attr_accessor :gen

    def initialize(name, xml, current_dir)
      @name, @xml, @current_dir = name, xml, current_dir
      parse_xml
    end

    def bind(generator)
      @gen = generator
    end

    def generator
      @gen || @parent.generator.class_generator
    end

    alias gen generator

    def to_s
      @gen.namespace(self)
    end

    def [](name)
      get_member(name.to_s) || klass(name)
    end

    def function(name)
      member = get_member(name.to_s)
      member.kind_of?(Function) ? member : nil
    end

    def klass(name)
      get_class(name.to_s)
    end

    def classes
      @classes ||= begin
        list = []
        @classes_hash.each do |name, member|
          list << get_class(name)
        end
        list.compact!
        list.sort
      end
    end

    private
      def parse_xml
        parse_members

        @classes_hash = {}
        (@xml/'innerclass').each do |klass|
          name = klass.innerHTML
          if name =~ /^#{@name}::(.+)$/
            name = $1
          end
          filename = klass.attributes['refid']
          filepath = File.join(@current_dir, "#{filename}.xml")
          if File.exist?(filepath)
            @classes_hash[name] = (Hpricot::XML(File.read(filepath))/'compounddef').first
          else
            @classes_hash[name] = "Could not open #{filepath}"
          end
        end
      end

      def get_class(name)
        if klass = @classes_hash[name]
          if klass.kind_of?(Hpricot::Elem)
            klass = @classes_hash[name] = make_member(name, klass)
          end
        end
        klass
      end
  end
end # Namespace
