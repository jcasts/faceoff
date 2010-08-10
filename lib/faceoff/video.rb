class Faceoff

  class Video

    TITLE_REG = /"video_title", "([^"]+)"/m
    SRC_REG   = /"video_src", "([^"]+)"/m
    ID_REG    = /"video_id", "([^"]+)"/m

    ##
    # Retrieve all 'Videos of Me'.

    def self.retrieve_all faceoff, options={}
      agent = faceoff.agent
      limit = options[:limit]
      start = options[:start] || 0

      page = agent.get "/video/?of=#{faceoff.profile_id}&s=#{start}"
      summary = page.search("div[@class='summary']").first.text
      video_count = ($2.to_i - 1) if summary =~ /(of|all) (\d+) videos/
      video_count = limit if limit && video_count > limit

      page = page.link_with(:href => %r{/video.php}).click

      videos = []

      video_count.times do |i|
        video_title = URI.decode($1.gsub('+', ' ')) if page.body =~ TITLE_REG
        video_src   = URI.decode($1) if page.body =~ SRC_REG
        video_id    = URI.decode($1) if page.body =~ ID_REG

        videos << new(video_id, video_src, video_title)

        next_link = page.link_with(:text => 'Next')
        break unless next_link

        page = next_link.click
      end

      videos
    end


    ##
    # Alias for Video::retrieve_all

    def self.videos_of_me faceoff, options={}
      retrieve_all faceoff, options
    end


    # Facebook video id.
    attr_accessor :fid

    # Url of the video.
    attr_accessor :url

    # Name of the video.
    attr_accessor :name


    def initialize id, url, name
      @fid  = id
      @url  = url
      @name = name
    end


    ##
    # Saves the video the the provided path.

    def save! target="./Videos of me"
      filename = File.join(target, "#{@name}#{File.extname(@url)}")

      data = Faceoff.download(@url)

      Faceoff.safe_save(filename) do |file|
        file.write data
      end
    end
  end
end
