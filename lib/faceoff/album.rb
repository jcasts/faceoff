class Faceoff

  class Album


    ##
    # Returns an array of albums.

    def self.retrieve_all faceoff, options={}
      albums = []
      limit  = options[:limit]
      start  = options[:start] || 0

      album_count = nil
      index = start

      while album_count.nil? || index < album_count do
        albums = albums.concat albums_at_index(faceoff, index)

        page = faceoff.agent.current_page

        unless album_count
          album_count = $1.to_i if page.body =~ /(\d+) Photo Albums/m
          album_count = limit if limit && album_count > limit
        end

        index = start + albums.length
      end

      albums[0..(album_count-1)]
    end


    ##
    # Get photo album information on one page starting at an album index.

    def self.albums_at_index faceoff, index
      agent = faceoff.agent
      page = agent.get "/photos.php?id=#{faceoff.profile_id}&s=#{index}"

      albums = []

      page.search("div[@class='info']/h2/a").each do |link|

        album_id   = $1 if link['href'] =~ /aid=(\d+)/
        album_name = link.text

        next unless album_id

        albums << new(faceoff, album_id, album_name)
      end

      albums
    end


    # Facebook album id.
    attr_accessor :fid

    # Name of the album.
    attr_accessor :name


    def initialize faceoff, id, name
      @faceoff = faceoff
      @agent   = faceoff.agent

      @fid    = id
      @name   = name
      @photos = nil
    end


    ##
    # Returns an array of photos.

    def photos reload=false
      return @photos if @photos && !reload

      options = {}
      options[:limit] = reload if Fixnum === reload

      @photos = Photo.photos_of_album @faceoff, @fid, options
    end
  end
end
