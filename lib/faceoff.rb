# Odd hack that makes the vpim-mechanize conflict disappear.
Vpim = Module.new

# Hack to fix old ruby version support of Vpim
class Array
  def to_str
    self.to_s
  end
end


require 'rubygems'
require 'mechanize'
require 'highline'

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
  VERSION = '1.0.1'

  # Command line actions available.
  ACTIONS = %w{albums friends notes photos_of_me profile_pictures videos_of_me}

  # Default directory to save data to.
  DEFAULT_DIR = "faceoff-#{Time.now.to_i}"


  ##
  # Create a new Faceoff instance and login.

  def self.login email, password
    inst = self.new email, password
    inst.login
    inst if inst.logged_in?
  end


  ##
  # Parse ARGVs

  def self.parse_args argv
    options = {}

    opts = OptionParser.new do |opt|
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

      opt.on('-A', '--all', 'Retrieve all facebook data') do
        ACTIONS.each{|a| options[a] = true }
      end

      opt.on('-a', '--albums [RANGE]', 'Retrieve albums') do |range|
        options['albums'] = parse_range range
      end

      opt.on('-f', '--friends [RANGE]', 'Retrieve contacts') do |range|
        options['friends'] = parse_range range
      end

      opt.on('-n', '--notes [RANGE]', 'Retrieve notes') do |range|
        options['notes'] = parse_range range
      end

      opt.on('-p', '--photosofme [RANGE]', 'Retrieve photos of me') do |range|
        options['photos_of_me'] = parse_range range
      end

      opt.on('-P', '--profilepics [RANGE]', 'Retrieve profile pics') do |range|
        options['profile_pictures'] = parse_range range
      end

      opt.on('-V', '--videosofme [RANGE]', 'Retrieve videos of me') do |range|
        options['videos_of_me'] = parse_range range
      end

      opt.on('-d', '--directory PATH', 'Directory to save to') do |path|
        options['dir'] = path
      end

      opt.on('-z', '--zip [NAME]', 'Zip content when done') do |name|
        options['zip'] = name || true
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
    str = str.to_s.strip

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

    directory = options['dir'] || "./#{email}"

    ACTIONS.each do |action|
      next unless options[action]
      dir = File.join directory, action.capitalize.gsub("_", " ")

      faceoff.send(action, options[action]) do |item|
        name = item.name rescue item.fid
        puts "Saving #{action} '#{name}'"
        item.save! dir
      end
    end

    if options['zip']
      zipfile = String === options['zip'] ? options['zip'] : directory
      success = system "zip -u #{zipfile}.zip #{directory}/**/*"

      FileUtils.rm_rf directory if success
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
    url = URI.parse("http://www.facebook.com")
    #puts @agent.cookie_jar.cookies(url).inspect
    @agent.cookie_jar.cookies(url).select{|c| c.name == "c_user" }.first
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

  def albums reload=false, &block
    return @albums if @albums && !reload
    @albums = Album.retrieve_all self, bracket_for(reload), &block
  end


  ##
  # Returns the logged in user's User object.

  def user reload=false
    return @user if @user && !reload
    @user = User.retrieve self, profile_id
  end


  ##
  # Returns an array of friends.

  def friends reload=false, &block
    if @friends && !reload
      @friends.each &block if block_given?
      return @friends
    end

    @friends = User.retrieve_all self, bracket_for(reload), &block
  end


  ##
  # Returns an array of notes.

  def notes reload=false, &block
    if @notes && !reload
      @notes.each &block if block_given?
      return @notes
    end

    @notes = Note.retrieve_all self, bracket_for(reload), &block
  end


  ##
  # Returns an array of photos of me.

  def photos_of_me reload=false, &block
    if @photos_of_me && !reload
      @photos_of_me.each &block if block_given?
      return @photos_of_me
    end

    @photos_of_me = Photo.photos_of_me self, bracket_for(reload), &block
  end


  ##
  # Returns an array of profile pictures photos.

  def profile_pictures reload=false, &block
    if @profile_pics && !reload
      @profile_pics.each &block if block_given?
      return @profile_pics
    end

    @profile_pics =
      Photo.photos_of_album self, :profile, bracket_for(reload), &block
  end


  ##
  # Returns the facebook profile id. Fetches it from the page if not set.

  def profile_id reload=false
    return @profile_id if @profile_id && !reload
    @profile_id = $1 if @agent.current_page.body =~ /\\"user\\":(\d+)/m
  end


  ##
  # Returns an array of videos of me.

  def videos_of_me reload=false, &block
    if @videos_of_me && !reload
      @videos_of_me.each &block if block_given?
      return @videos_of_me
    end

    @videos_of_me = Video.videos_of_me self, bracket_for(reload), &block
  end
end
