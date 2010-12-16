module Dub
  module OptsParser

    def self.extract_hash(xml)
      (xml/'simplesect').each do |x|
        if (x/'title').inner_html == 'Bindings info:'
          (x/'title').remove()
          (x/'ref').each do |r|
            r.swap(r.inner_html)
          end
          code = EntitiesUnescape::Decoder.decode((x/'para').inner_html)
          return self.parse(code)
        end
      end
      nil
    end

    def self.parse(src)
      res = {}
      while !src.empty?
        src = src.sub(/^\s*([^:]+):\s*('[^']+'|"[^"]+")\s*,?\s*/m) do
          res[$1.to_sym] = $2[1..-2]
          ''
        end
      end
      res
    end
  end # OptsParser
end # Dub

