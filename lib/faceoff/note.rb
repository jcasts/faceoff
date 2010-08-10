class Faceoff

  class Note

    CONTENT_CLASSES = "note_content text_align_ltr direction_ltr clearfix"

    ##
    # Returns an array of notes.

    def self.retrieve_all faceoff, options={}
      agent = faceoff.agent
      limit = options[:limit]
      start = options[:start] || 0

      note_count = limit
      index = start

      notes = []
      page  = agent.current_page

      while !limit || notes.length < limit && page.link_with(:text => "Next") do
        notes = notes.concat notes_at_index(faceoff, index)
        page  = agent.current_page
        index = start + notes.length

        last_link = page.link_with(:text => 'Last')
        limit ||= $1.to_i + 10 if
          last_link && last_link.href =~ %r{/notes.php\?id=\d+&start=(\d+)}
        limit ||= 10
      end

      notes[0..(limit-1)]
    end


    ##
    # Get notes on one page starting at a note index.

    def self.notes_at_index faceoff, index
      agent = faceoff.agent
      page  = agent.get "/notes.php?id=#{faceoff.profile_id}&start=#{index}"

      notes = []

      page.search("div[@class='note_body']").each do |div|
        title_link = div.search("div[@class='note_title']/a").first
        id    = $1 if title_link['href'] =~ %r{/note\.php\?note_id=(\d+)}
        title = title_link.text
        date  = Time.parse div.search("div[@class='byline']").first.text
        body  = div.search("div[@class='#{CONTENT_CLASSES}']/div").first.text

        notes << new(id, title, body, date)
      end

      notes
    end


    # Facebook id of the note.
    attr_accessor :fid

    # Note title.
    attr_accessor :title

    # Note contents.
    attr_accessor :body

    # Date note was created at.
    attr_accessor :date


    def initialize id, title, body, date=nil
      @fid   = id
      @title = title
      @body  = body
      @date  = date || Time.now
    end


    ##
    # Saves the note to the provided file path.

    def save! target="./Notes"
      filename = File.join(target, "#{@title}.txt")

      Faceoff.safe_save(filename) do |file|
        file.write self.to_s
      end
    end


    ##
    # Returns the object as a string with title, date, and body.

    def to_s
      "#{@title}\n#{@date.to_s}\n\n#{@body}"
    end
  end
end
