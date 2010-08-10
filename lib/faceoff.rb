require 'rubygems'
require 'mechanize'
require 'highline'

Vpim = Module.new # Odd hack that makes the vpim-mechanize conflict disappear.
require 'vpim/vcard'

require 'optparse'
require 'json'
require 'time'
require 'fileutils'

class Faceoff

  require 'faceoff/pagelet'
  require 'faceoff/note'
  require 'faceoff/photo'
  require 'faceoff/album'
  require 'faceoff/video'
  require 'faceoff/user'


  # Version of the gem.
  VERSION = '1.0.0'

  # Command line actions available.
  ACTIONS = %w{albums friends notes photos_of_me profile_pictures videos_of_me}

  # Default directory to save data to.
  DEFAULT_DIR = "faceoff-#{Time.now.to_i}"


  ##
  # Create a new Faceoff instance and login.

  def self.login email, password
    inst = new email, password
    inst if inst.login
  end


  ##
  # Parse ARGVs

  def self.parse_args argv
    options = {}

    OptionParser.new do |opt|
      opt.program_name = File.basename $0
      opt.version = Faceoff::VERSION
      opt.release = nil

      opt.banner = <<-STR
Faceoff is a facebook scraper that allows you to download and backup
your content in a reusable format.

  Usage:
    #{opt.program_name} -h/--help
    #{opt.program_name} -v/--version
    #{opt.program_name} [facebook_email [password]] [options...]

  Examples:
    #{opt.program_name} example@yahoo.com --all
    #{opt.program_name} example@yahoo.com --albums '2..3'
    #{opt.program_name} example@yahoo.com --friends --profilepics 0

  Options:
      STR

      opt.on('-A', '--all') do
        ACTIONS.each{|a| options[a] = true }
      end

      opt.on('-a', '--albums [RANGE]') do |range|
        options['albums'] = parse_range range
      end

      opt.on('-d', '--directory PATH') do |path|
        options['dir'] = path
      end

      opt.on('-f', '--friends [RANGE]') do |range|
        options['friends'] = parse_range range
      end

      opt.on('-n', '--notes [RANGE]') do |range|
        options['notes'] = parse_range range
      end

      opt.on('-p', '--photosofme [RANGE]') do |range|
        options['photos_of_me'] = parse_range range
      end

      opt.on('-P', '--profilepics [RANGE]') do |range|
        options['profile_pictures'] = parse_range range
      end

      opt.on('-V', '--videosofme [RANGE]') do |range|
        options['videos_of_me'] = parse_range range
      end
    end

    opts.parse! argv

    options['email'], options['password'] = argv

    options
  end


  ##
  # Takes a range or number as a string and returns a range or integer.
  # Returns true if no range or int value is found.

  def self.parse_range str
    str = str.strip

    return Range.new($1.to_i, $2.to_i) if str =~ /^(\d+)\.\.(\d+)$/
    return str.to_i if str == str.to_i.to_s

    true
  end


  ##
  # Run from the command line.

  def self.run argv
    options = parse_args argv

    $stdin.sync
    input = HighLine.new $stdin

    faceoff = nil

    until faceoff do
      email    = options['email'] || input.ask("Facebook Email: ")
      password = options['password'] ||
        input.ask("Facebook Password: "){|i| i.echo = false}

      faceoff = login email, password
      options['password'] = nil unless faceoff
    end
  end


  ##
  # Download a photo from a url. Pass a block to catch the data.

  def self.download url
    uri = URI.parse url

    resp = Net::HTTP.start(uri.host) do |http|
      http.get uri.path
    end

    resp.body
  end


  ##
  # Safely save a file; rename it if name exists.

  def self.safe_save filename, &block
    dir = File.dirname(filename)

    FileUtils.mkdir_p dir
    raise "Invalid directory #{dir}" unless File.directory? dir

    test_filename = filename

    i = 0
    while File.file?(test_filename)
      i = i.next
      ext = File.extname filename

      test_filename = File.join File.dirname(filename),
                                "#{File.basename(filename, ext)} (#{i})#{ext}"
    end

    filename = test_filename

    File.open(filename, "w+") do |f|
      block.call(f) if block_given?
    end
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
