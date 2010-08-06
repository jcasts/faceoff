require 'rubygems'
require 'mechanize'
require 'highline'
require 'json'
require 'time'

class Faceoff

  require 'faceoff/pagelet'
  require 'faceoff/note'
  require 'faceoff/photo'
  require 'faceoff/album'
  require 'faceoff/video'
  require 'faceoff/user'


  VERSION = '1.0.0'


  ##
  # Run from the command line.

  def self.run argv
    output_dir = argv[0]
    raise "Invalid target directory" unless File.directory? output_dir

    $stdin.sync
    input = HighLine.new $stdin

    email    = input.ask "Facebook Email: "
    password = input.ask("Facebook Password: "){|i| i.echo = false}

    faceoff = login email, password
  end


  ##
  # Create a new Faceoff instance and login.

  def self.login email, password
    inst = new email, password
    inst.login
    inst
  end



  # Mechanize agent
  attr_accessor :agent

  # User email
  attr_accessor :email

  # User password
  attr_accessor :password

  # Facebook profile id
  attr_writer :profile_id


  ##
  # Instantiate with user information.

  def initialize email, password
    @email      = email
    @password   = password
    @profile_id = nil

    @agent = Mechanize.new
    @agent.user_agent_alias = 'Mac Safari'
    @agent.redirect_ok = true

    @albums = nil
    @friends = nil
    @notes = nil
    @photos_of_me = nil
    @profile_pics = nil
    @videos_of_me = nil
  end


  ##
  # Returns an options hash based on the type of input:
  #   bracket_for 5
  #   # => {:limit => 5}
  #
  #   bracket_for 3..5
  #   # => {:limit => 3, :start => 3}
  #
  #   bracket_for true
  #   # => {}

  def bracket_for obj
    case obj
    when Fixnum then {:limit => obj}
    when Range  then {:limit => obj.entries.length, :start => obj.first}
    else {}
    end
  end


  ##
  # Check if we're logged into facebook.

  def logged_in?
    !@agent.cookie_jar.cookies(URI.parse("http://www.facebook.com")).empty?
  end


  ##
  # Login to facebook.

  def login
    page = @agent.get("http://www.facebook.com")
    form  = page.form_with \
      :action => 'https://login.facebook.com/login.php?login_attempt=1'

    return unless form

    form.email = @email
    form.pass  = @password

    page = form.submit
    logged_in?
  end


  ##
  # Returns an array of photo albums.

  def albums reload=false
    return @albums if @albums && !reload
    @albums = Album.retrieve_all self, bracket_for(reload)
  end


  ##
  # Returns the logged in user's User object.

  def user reload=false
    return @user if @user && !reload
    @user = User.retrieve self, profile_id
  end


  ##
  # Returns an array of friends.

  def friends reload=false
    return @friends if @friends && !reload
    @friends = User.retrieve_all self, bracket_for(reload)
  end


  ##
  # Returns an array of notes.

  def notes reload=false
    return @notes if @notes && !reload
    @notes = Note.retrieve_all self, bracket_for(reload)
  end


  ##
  # Returns an array of photos of me.

  def photos_of_me reload=false
    return @photos_of_me if @photos_of_me && !reload
    @photos_of_me = Photo.photos_of_me self, bracket_for(reload)
  end


  ##
  # Returns an array of profile pictures photos.

  def profile_pictures reload=false
    return @profile_pics if @profile_pics && !reload
    @profile_pics = Photo.photos_of_album self, :profile, bracket_for(reload)
  end


  ##
  # Returns the facebook profile id. Fetches it from the page if not set.

  def profile_id reload=false
    return @profile_id if @profile_id && !reload
    @profile_id = $1 if @agent.current_page.body =~ /\\"user\\":(\d+)/m
  end


  ##
  # Returns an array of videos of me.

  def videos_of_me reload=false
    return @videos_of_me if @videos_of_me && !reload
    @videos_of_me = Video.videos_of_me self, bracket_for(reload)
  end
end
