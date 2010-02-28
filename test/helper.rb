require 'rubygems'
require 'test/unit'
require 'shoulda'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'doxy_generator'

class Test::Unit::TestCase

  def self.fixture(path)
    File.join(File.dirname(__FILE__), 'fixtures', path)
  end

  @@namespacecv_xml = DoxyGenerator.parse(fixture('namespacecv.xml'))

  def fixture(path)
    self.fixture(path)
  end

  def namespacecv_xml
    @@namespacecv_xml
  end
end
