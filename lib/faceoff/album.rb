class Faceoff

  class Album


    ##
    # Returns an array of albums for the current user. Pass the :user_id option
    # to override the logged in user.

    def self.retrieve_all faceoff, options={}
      albums = []
      limit  = options[:limit]
      start  = options[:start] || 0

      agent   = faceoff.agent
      user_id = options[:user_id] || faceoff.profile_id

      page = agent.get "/photos.php?id=#{user_id}"

      xpath = "table[@class='uiGrid fbPhotosGrid']/tbody/"+
              "/div[@class='pls photoDetails']/a"

      page.search(xpath).each do |node|
        album_id   = $1 if node['href'] =~ /aid=(\d+)/
        album_name = node.text
        albums << new(faceoff, album_id, album_name)
      end

      limit ||= albums.length

      albums[start, limit]
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
