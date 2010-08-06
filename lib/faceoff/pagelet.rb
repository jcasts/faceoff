class Faceoff

  ##
  # The pagelet class is used to parse out facebook javascript dynamic content
  # on a given html page.

  class Pagelet

    ##
    # Parses an html string and returns a hash of
    # Nokogiri::HTML::Document objects, indexed by page area:
    #   Pagelet.parse html
    #   #=> {:profile_photo => <#OBJ>, :top_bar => <#OBJ>...}
    #
    #   Pagelet.parse html, :profile_photo
    #   #=> <#OBJ>

    def self.parse html, type=nil
      pagelet = nil

      matches = html.scan regex_for(type)

      matches.each do |name, html|
        html     = JSON.parse("[\"#{html}\"]").first
        html_doc = Nokogiri::HTML.parse html
        return html_doc if type

        pagelet ||= {}
        pagelet[name.to_sym] = html_doc
      end

      pagelet
    end


    ##
    # Returns a regex to retrieve the given pagelet.

    def self.regex_for name
      name ||= "\\w+"
      %r{<script>.*"pagelet_(#{name})":"(.*)"\},"page_cache":.*\}\);</script>}
    end
  end
end
