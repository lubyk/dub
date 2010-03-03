require 'dub/member_extraction'

module Dub

  class Namespace
    include MemberExtraction
    attr_accessor :name, :gen, :xml, :enums, :parent, :header, :prefix, :defines

    def initialize(name, xml, current_dir)
      @name, @xml, @current_dir = name, xml, current_dir
      @class_alias = {}
      @alias_names = []
      @enums   = []
      @defines = []
      parse_xml
    end

    def bind(generator)
      self.gen = generator.namespace_generator
    end

    def gen=(generator)
      @gen = generator
      @gen_members = nil
    end

    def generator
      @gen
    end

    def class_generator
      @gen && @gen.class_generator
    end

    def function_generator
      @gen && @gen.function_generator
    end

    alias gen generator

    def to_s
      @gen.namespace(self)
    end

    def merge!(group)
      raise "Can only merge with a Group" unless group.kind_of?(Group)
      @defines += group.defines
      @enums   += group.enums

      # TODO: do we need to merge classes and members ? I don't think so (they should be in namespace).
    end

    def full_type
      @parent ? "#{@parent.full_type}::#{name}" : name
    end

    def lib_name
      prefix ? "#{prefix}_#{name}" : name
    end

    def id_name(name = self.name)
      prefix ? "#{prefix}.#{name}" : name
    end

    def header
      @header ||= (@xml/'location').first.attributes['file'].split('/').last
    end

    def [](name)
      get_member(name.to_s) || klass(name.to_s)
    end

    def function(name)
      member = get_member(name.to_s)
      member.kind_of?(Function) ? member : nil
    end

    def klass(name)
      get_class(name.to_s, @classes_hash) || get_alias(name.to_s)
    end

    def template_class(name)
      get_class(name.to_s, @t_classes_hash)
    end

    def classes
      @classes ||= begin
        list = []
        @classes_hash.each do |name, member|
          list << get_class(name, @classes_hash)
        end
        list.compact!
        list.sort
      end
    end

    def members
      if self.generator
        @gen_members ||= self.generator.members_list(super)
      else
        super
      end
    end

    def has_constants?
      has_enums? || has_defines?
    end

    def has_enums?
      !@enums.empty?
    end

    def has_defines?
      !@defines.empty?
    end

    def register_alias(name, klass)
      @class_alias[name] = klass
    end

    private
      def parse_xml
        parse_enums
        parse_members
        parse_classes
      end

      def parse_enums
        @enums = (@xml/"enumvalue/name").map{|e| e.innerHTML}
      end

      # We do not run this by default but use groups to make sure we do
      # not cluter namespace
      def parse_defines
        @defines = (@xml/"memberdef[@kind=define]").map do |e|
          if (e/'param').first
            nil
          else
            (e/'name').innerHTML
          end
        end.compact
      end

      def parse_classes
        @classes_hash   = {}
        @t_classes_hash = {}
        @classes_by_ref = {}
        (@xml/'innerclass').each do |klass|
          name = klass.innerHTML
          if name =~ /^#{@name}::(.+)$/
            name = $1
          end
          filename = klass.attributes['refid']
          filepath = File.join(@current_dir, "#{filename}.xml")
          if File.exist?(filepath)
            class_xml = (Hpricot::XML(File.read(filepath))/'compounddef').first
            if (class_xml/'/templateparamlist/param').innerHTML != ''
              @t_classes_hash[name] = class_xml
            else
              @classes_hash[name] = class_xml
            end
            @classes_by_ref[class_xml[:id]] = class_xml
          else
            Dub.logger.warn "Could not open #{filepath}"
            nil
          end
        end
        parse_template_class_typedefs
      end

      def parse_template_class_typedefs
        (@xml/'memberdef[@kind=typedef]').each do |typedef_xml|
          # <type><ref refid="classdoxy_1_1_t_mat" kindref="compound">TMat</ref>&lt; float &gt;</type>
          if id = (typedef_xml/'/type/ref').first
            id = id[:refid]
          end

          new_name = (typedef_xml/'name').innerHTML

          if ref_class = @classes_by_ref[id]
            if (typedef_xml/'/type').innerHTML =~ /&gt;$/
              # template typedef
              old_name = (ref_class/'/compoundname').first.innerHTML.gsub(/^.*::/,'')

              # replace class name
              class_def = ref_class.to_s.gsub(/#{old_name}&lt;.*?&gt;::/,"#{new_name}::")
              class_def = class_def.gsub(/#{old_name}/, new_name)

              # replace template types
              # get template parameters
              ttypes = (ref_class/'/templateparamlist/param').map do |param|
                if type = (param/'declname').first
                  type.innerHTML
                else
                  (param/'type').innerHTML.gsub(/^\s*(typename|class)\s+/,'')
                end
              end

              types_map = {}
              instanciations_params = []
              (typedef_xml/'/type').innerHTML[/&lt;\s*(.*)\s*&gt;$/,1].split(',').map(&:strip).each_with_index do |type, i|
                instanciations_params << type
                types_map[ttypes[i]] = type
              end

              class_xml = (Hpricot::XML(class_def)/'compounddef').first

              (class_xml/'*[@prot=private]').remove
              (class_xml/'templateparamlist').remove
              (class_xml/'').append("<originaltemplate>#{old_name}</originaltemplate>")
              (ref_class/'').append("<instanciation><name>#{new_name}</name><param>#{instanciations_params.join('</param><param>')}</param></instanciation>")

              types_map.each do |template_type, real_type|
                (class_xml/'type').each do |t|
                  if t.innerHTML == template_type
                    t.swap("<type>#{real_type}</type>")
                  end
                end
              end

              @classes_hash[new_name] = class_xml
            else
              # alias
              original_name = (typedef_xml/'/type/ref').innerHTML
              if class_xml = @classes_hash[original_name]
                @alias_names << new_name
                if (class_xml/'/aliases').first
                  (class_xml/'/aliases').append("<name>#{new_name}</name>")
                else
                  (class_xml/'').append("<aliases><name>#{new_name}</name></aliases>")
                end
              else
                Dub.logger.warn "Could not find original class #{original_name}"
              end
            end
          else
            Dub.logger.warn "Could not find reference class #{id}"
          end
        end
      end

      def get_class(name, source)
        if klass = source[name]
          if klass.kind_of?(Hpricot::Elem)
            klass = source[name] = make_member(name, klass)
          end
        end
        klass
      end

      def get_alias(name)
        if klass = @class_alias[name]
          return klass
        elsif @classes || !@alias_names.include?(name)
          # classes parsed, alias does not exist
          nil
        else
          # we need to parse all classes so they register the alias
          self.classes
          @class_alias[name]
        end
      end
  end
end # Namespace
