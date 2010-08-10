class Faceoff

  class Album


    ##
    # Returns an array of albums for the current user. Pass the :user_id option
    # to override the logged in user.

    def self.retrieve_all faceoff, options={}, &block
      albums = []
      limit  = options[:limit]
      start  = options[:start] || 0

      agent   = faceoff.agent
      user_id = options[:user_id] || faceoff.profile_id

      page = agent.get "/photos.php?id=#{user_id}"

      xpath = "table[@class='uiGrid fbPhotosGrid']/tbody/"+
              "/div[@class='pls photoDetails']/a"

      nodes = page.search(xpath)

      limit ||= nodes.length

      nodes[start, limit].each do |node|
        album_id   = $1 if node['href'] =~ /aid=(\d+)/
        album_name = node.text

        albums << new(faceoff, album_id, album_name)

        yield albums.last if block_given?
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

    def photos reload=false, &block
      if @photos && !reload
        @photos.each &block if block_given?
        return @photos
      end

      options = {}
      options[:limit] = reload if Fixnum === reload

      @photos = Photo.photos_of_album @faceoff, @fid, options, &block
    end


    ##
    # Save the album to the provided directory.

    def save! target="./Albums"
      dirname = File.join target, @name
      FileUtils.mkdir_p dirname

      self.photos{|p| p.save! dirname}
    end
  end
end
