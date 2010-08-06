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

      user.emails = fattr details, 'Email'

      user.phones['mobile'] =
        fattr(details, 'Mobile Number').first.gsub(/[^\da-z]/i, '') rescue nil

      user.phones['main'] =
        fattr(details, 'Phone').first.gsub(/[^\da-z]/i, '') rescue nil


      user.photo = pagelets[:profile_photo].css("img#profile_pic").first['src']

      user.address = fattr details, "Current Address"

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

    def self.fattr doc, attrib
      resp  = []

      nodes = doc.search("th[@class='label'][text()='#{attrib}:']")

      return resp if nodes.empty?

      nodes.first.next.children.each do |node|
        text = node.text.strip
        next if text.empty?
        resp << text
      end

      resp
    end


    # Facebook user id.
    attr_accessor :fid

    # User's name.
    attr_accessor :name

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
      @address = nil
    end
  end
end
