class Faceoff

  class User

    IM_SERVICES = ['AIM', 'Yahoo', 'Skype', 'Google Talk', 'Windows Live',
      'Gadu-Gadu', 'QQ', 'ICQ', 'Yahoo Japan', 'NateOn']


    ##
    # Retrieve all friends of the given faceoff user.

    def self.retrieve_all faceoff, options={}
      agent = faceoff.agent
      limit = options[:limit]
      start = options[:start] || 0

      page = agent.get "/friends/ajax/superfriends.php?"+
        "__a=1&filter=afp&type=afp&value&is_pagelet=false&offset=0"

      user_ids = JSON.parse $1 if page.body =~ %r{"members":(\[[^\]]+\])}
      limit ||= user_ids.length

      user_ids[start, limit].map{|uid| retrieve faceoff, uid}
    end


    ##
    # Retrieve a single user based on the user's id or alias:
    #   User.retrieve f, 12345
    #   User.retrieve f, 'bob.smith'

    def self.retrieve faceoff, user_id
      agent = faceoff.agent

      path = if user_id =~ /^\d+$/
               "/profile.php?id=#{user_id}&v=info&ref=sgm"
             else
               "/#{user_id}?v=info"
             end

      page = agent.get path

      pagelets = Pagelet.parse page.body

      name = pagelets[:top_bar].css("h1#profile_name").first.text
      id   = $1 if
        pagelets[:top_bar].css("a#top_bar_pic").first['href'] =~
        %r{/profile\.php\?id=(\d+)}


      user = User.new id, name

      details = pagelets[:tab_content]

      birthday = fattr(details, 'Birthday')[0].strip
      user.birthday = Time.parse birthday if birthday && !birthday.empty?

      user.emails = fattr details, 'Email'

      user.phones['mobile'] =
        fattr(details, 'Mobile Number').first.gsub(/[^\da-z]/i, '') rescue nil

      user.phones['main'] =
        fattr(details, 'Phone').first.gsub(/[^\da-z]/i, '') rescue nil


      user.photo = pagelets[:profile_photo].css("img#profile_pic").first['src']

      user.address = {}
      user.address[:street] = fattr(details, "Address", :href => /&a2=/).first

      user.address[:city], user.address[:state] =
        fattr(details, "Address", :href => /&c2=/).first.to_s.split(", ")

      user.address[:state], user.address[:country] =
        [nil, user.address[:state]] if user.address[:state].to_s.length > 2

      user.address[:zip] = fattr(details, "Address", :href => /&z2=/).first


      IM_SERVICES.each do |im|
        im_alias = fattr(details, im).first
        next unless im_alias
        user.aliases[im] = im_alias
      end

      user.aliases['Facebook'] = $1 if
        fattr(details, 'Facebook Profile').first =~ /([^\/]+)$/

      user
    end


    ##
    # Get a facebook attribute from a given Nokogiri::HTML::Document.

    def self.fattr doc, attrib, options={}
      resp  = []

      nodes = doc.search("th[@class='label'][text()='#{attrib}:']")

      return resp if nodes.empty?

      nodes.first.next.children.each do |node|
        text = node.name == "img" ? node['src'] : node.text.strip
        next if text.empty?

        if options.empty?
          resp << text
        else
          options.each do |key, matcher|
            resp << text if node[key] =~ matcher
          end
        end
      end

      resp
    end


    # Facebook user id.
    attr_accessor :fid

    # User's name.
    attr_accessor :name

    # User's birthday.
    attr_accessor :birthday

    # Facebook profile image.
    attr_accessor :photo

    # All emails.
    attr_accessor :emails

    # Instant message aliases.
    attr_accessor :aliases

    # Phone numbers.
    attr_accessor :phones

    # Current address.
    attr_accessor :address


    def initialize id, name
      @fid  = id
      @name = name

      @photo   = nil
      @phones  = {}
      @emails  = []
      @aliases = {}
      @address = {}
    end


    ##
    # Saves the user as a vcard to the provided file path.

    def save! target=".", vcard=nil
      FileUtils.mkdir_p target
      raise "Invalid directory #{target}" unless File.directory? target

      vcard = to_vcard vcard

      Faceoff.safe_save(File.join(target, "#{@name}.vcf")) do |file|
        file.write vcard
      end
    end


    ##
    # Returns a Vpip::Vcard object.

    def to_vcard vcard=nil
      vcard ||= Vpim::Vcard.create

      vcard.make do |maker|

        maker.name{|n| n.fullname = @name }

        maker.add_field Vpim::DirectoryInfo::Field.create('BDAY',
          @birthday.strftime("%Y-%m-%d"))

        maker.add_addr do |addr|
          addr.region   = address[:state]
          addr.locality = address[:city]
          addr.street   = address[:street]
          addr.country  = address[:country]
          addr.postalcode = address[:zip]
        end

        emails.each{|email| maker.add_email email }

        phones.each do |type, number|
          next unless number
          maker.add_tel(number){|tel| tel.location = [type] }
        end

        aliases.each do |name, value|
          maker.add_field Vpim::DirectoryInfo::Field.create("X-#{name}", value)
        end

        maker.add_photo do |photo|
          photo.image = Photo.download @photo
          photo.type  = File.extname(@photo)[1..-1]
        end if @photo
      end

      vcard
    end
  end
end


# Hack to fix old ruby version support of Vpim
class Object
  def to_str
    self.to_s
  end
end
