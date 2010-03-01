require 'doxy_generator'
require 'doxy_generator/lua'

parsed_file = DoxyGenerator.parse(Pathname(__FILE__).dirname + 'xml/namespacedoxy.xml')

doxy = parsed_file[:doxy]


DoxyGenerator::Lua.bind(doxy)
puts doxy

puts doxy[:Matrix]
