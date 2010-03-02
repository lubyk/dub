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
      get_member(name.to_s) || klass(name.to_s)
    end

    def function(name)
      member = get_member(name.to_s)
      member.kind_of?(Function) ? member : nil
    end

    def klass(name)
      get_class(name.to_s, @classes_hash)
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

    private
      def parse_xml
        parse_members

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
            @classes_hash[name] = "Could not open #{filepath}"
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
              ttypes = (ref_class/'/templateparamlist/param/type').map do |type|
                type.innerHTML.gsub(/^\s*(typename|class)\s+/,'')
              end

              types_map = {}

              (typedef_xml/'/type').innerHTML[/&lt;\s*(.*)\s*&gt;$/,1].split(',').map(&:strip).each_with_index do |type, i|
                types_map[ttypes[i]] = type
              end

              class_xml = (Hpricot::XML(class_def)/'compounddef').first

              (class_xml/'*[@prot=private]').remove
              (class_xml/'templateparamlist').remove


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
                if (class_xml/'/aliases').first
                  (class_xml/'/aliases').append("<name>#{new_name}</name>")
                else
                  (class_xml/'').append("<aliases><name>#{new_name}</name></aliases>")
                end
              else
                # TODO: enable log levels
                # puts "Could not find original class #{original_name}"
              end
            end
          else
            # TODO: enable log levels
            # puts "Could not find reference class #{id}"
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
  end
end # Namespace