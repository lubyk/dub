module Dub
  module EntitiesUnescape
    ENTITIES = {
      '&amp;' => '&',
      '&lt;'  => '<',
      '&gt;'  => '>'
    }

    def unescape(str)
      ENTITIES.each do |k,v|
        str.gsub!(k, v)
      end
      str
    end
  end
end