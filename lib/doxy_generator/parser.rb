require 'rubygems'
require 'hpricot'
require 'doxy_generator/namespace'

module DoxyGenerator
  class Parser
    def initialize(filepath)
      @current_dir = File.dirname(filepath)
      @xml = Hpricot::XML(File.read(filepath))
    end

    def [](name)
      namespaces[name.to_s]
    end

    def namespace(name)
      namespaces[name.to_s]
    end

    def namespaces
      @namespaces ||= begin
        ns = {}
        (@xml/'compounddef[@kind=namespace]').each do |namespace|
          name = (namespace/"compoundname").innerHTML
          ns[name] = DoxyGenerator::Namespace.new(name, namespace, @current_dir)
        end
        ns
      end
    end
  end # Parser
end

=begin
    def unescape_html(str)
      { '&amp;' => '&',
        '&lt;'  => '<',
        '&gt;'  => '>'
      }.each do |k,v|
        str.gsub!(k, v)
      end
      str
    end

    def print_method(class_name, name, arguments)
      name = name.sub!(%r{#{class_name}::},'')
      puts unescape_html("  #{name}#{arguments}")
    end
  end

class ClassParser < Parser
  def print
    @doc.search("compounddef").each do |klass|
      class_name = klass.search("compoundname").innerHTML
      puts class_name
      klass.search("memberdef[@kind=function]").each do |fnt|
        print_method(class_name, fnt.search(:definition).innerHTML, fnt.search(:argsstring).innerHTML)
      end
    end
  end
end

class NamespaceParser < Parser
  def print
    @doc.search("compounddef[@kind=namespace]").each do |namespace|
      namespace_name = namespace.search("compoundname").innerHTML
      puts namespace_name

      namespace.search("memberdef[@kind=function]").each do |fnt|
        print_method(namespace_name, fnt.search(:definition).innerHTML, fnt.search(:argsstring).innerHTML)
      end
    end
  end

  def lua_method(name)
    fnt = function(name)
    f = [:file, :line].map do |k|
      (fnt/'location').first[k]
    end
    puts "/* #{f.join(':')} */"
    puts "int #{prefix}#{name}"
  end

  private
    def prefix
      @prefix ||= begin
        "#{@doc.search("compounddef[@kind=namespace]").search("compoundname").innerHTML}_"
      end
    end

    def function(name)
      functions.detect {|f| f.search("definition").innerHTML =~ %r{#{name}} }
    end

    def functions
      @functions ||= @doc.search("compounddef[@kind=namespace]").first.search("memberdef[@kind=function]")
    end
end

#ClassParser.new("classcv_1_1_mat.xml").print
puts "\n\n--------------------------------------\n\n"
cv = NamespaceParser.new("namespacecv.xml")

#cv.print

cv.lua_method('resize')

=end