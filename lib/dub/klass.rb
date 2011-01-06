module Dub
  module MemberExtraction
  end
end
require 'dub/member_extraction'

module Dub
  class Klass
    include MemberExtraction
    attr_reader :name, :xml, :prefix, :constructor, :alias_names, :enums, :parent, :instanciations
    attr_accessor :opts

    def initialize(parent, name, xml, prefix = '')
      @parent, @name, @xml, @prefix = parent, name, xml, prefix

      @alias_names = []
      @enums       = []
      @ignores     = []
      @instanciations = {}
      @opts        = {}
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

    def ignore(list)
      list = [list].flatten
      @ignores += list
      @ignores.uniq!
      @gen_members = nil
    end

    def members
      list = super(@ignores)
      if self.generator
        @gen_members ||= self.generator.members_list(list.reject {|m| m.constructor?})
      else
        list
      end
    end

    def <=>(other)
      (name || "") <=> (other.name || "")
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

    def has_constants?
      has_enums?
    end

    def has_enums?
      !@enums.empty?
    end

    # Special or no destructor: class construction
    # and method calls are treated differently because
    # the object can be destroyed out of Lua (and Lua
    # should call a special method on garbage collection).
    def custom_destructor?
      @opts[:destructor]
    end

    # Use a static method as constructor.
    def custom_constructor?
      @opts[:constructor]
    end

    def template_params
      @template_params
    end

    def class_with_params(template_params)
      @instanciations[template_params]
    end

    def register_instanciation(template_params, klass)
      @instanciations[template_params] = klass
    end

    def source
      loc = (@xml/'location').first.attributes
      "#{loc['file'].split('/')[-3..-1].join('/')}:#{loc['line']}"
    end

    def header
      @opts[:header] ||= (@xml/'location').first.attributes['file'].split('/').last
    end

    def full_type
      @parent ? "#{@parent.full_type}::#{name}" : name
    end

    def lib_name
      @opts[:lib_name] || name
    end

    def id_name(name = self.name)
      "#{prefix}.#{name}"
    end

    def destructor_name
      "#{name}_destructor"
    end

    def is_deleted_name
      "#{name}_deleted"
    end

    def tostring_name
      "#{name}__tostring"
    end

    def constructor
      if custom_constructor?
        # Using a static member built with member list
        return nil
      end
      
      if defined?(@constructor)
        @constructor
      else
        self.members
        @constructor ||= nil
      end
      @constructor
    end

    def names
      [@name] + @alias_names
    end

    private
      def parse_xml
        parse_opts_hash
        parse_enums
        parse_members
        parse_template_params
        parse_instanciations
        parse_alias_names
      end

      def parse_opts_hash
        if hash = Dub::OptsParser.extract_hash(@xml)
          if hash.kind_of?(Hash)
            if ignore = hash[:ignore]
              self.ignore(ignore.split(',').map(&:strip))
            end
            @opts.merge!(hash)
          else
            raise "Could not parse @dub parameters #{hash.inspect}"
          end
        end
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

      def parse_instanciations
        (@xml/'instanciation').each do |klass|
          name   = (klass/'name').innerHTML
          params = (klass/'param').map do |p|
            p.innerHTML
          end

          @instanciations[params] = @parent[name]
        end
      end

      def parse_alias_names
        (@xml/'aliases/name').each do |name|
          name = name.innerHTML
          if name.size < @name.size
            @alias_names << @name
            change_name(name)
          else
            @alias_names << name
          end

          if @parent
            @parent.register_alias(name, self)
          end
        end
      end

      def make_member(name, xml)
        member = super
        return nil unless member

        if names.include?(name)
          member.name = @name # force key name
          member.set_as_constructor

          # special handling of constructors
          if @constructor.kind_of?(FunctionGroup)
            @constructor << member
          elsif @constructor
            list = Dub::FunctionGroup.new(self)
            list << @constructor
            list << member
            @constructor = list
          else
            @constructor = member
          end
        end

        member
      end

      def change_name(new_name)
        @name = new_name
        if @constructor.kind_of?(Array)
          @constructor.each do |c|
            c.name = new_name
          end
        elsif @constructor
          @constructor.name = new_name
        end
      end

      def method_missing(met, *args)
        if args.empty? && @opts.has_key?(met.to_sym)
          @opts[met.to_sym]
        elsif args.size == 1 && met.to_s =~ /^(.+)=$/
          @opts[$1.to_sym] = args.first
        else
          super
        end
      end

      def ignore_member?(member)
        if custom_destructor?
          if member.name == opts[:destructor] || member.name == 'set_userdata_ptr'
            return true
          end
        end
        if custom_constructor?
          if member.constructor?
            return true
          end
        end
        super
      end

  end
end