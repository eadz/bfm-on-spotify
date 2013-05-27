require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'active_record'
require 'sqlite3'
require 'logger'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => "_code/songs.sqlite3")
ActiveRecord::Base.logger = Logger.new(STDOUT)

# ActiveRecord::Migration.create_table :songs do |t|
#   t.string :song_name
#   t.string :spotify_id
#   t.timestamps
# end

@topsongs = {}

class Song < ActiveRecord::Base
end

def get_songs_from_djpage(djpage)
  songs = djpage.at_css("ul.djextra").children.map{|c| c.text.gsub(/\n|\t/,' ').gsub(/ {1,99}/,' ').strip}.compact
  songs.delete_if{|s| s == ""}
  songs.map!{|s| s.split("[").first }
  i = 1
  while(i < songs.length)
    if songs[i][0].ord == 8211 # Zac and Ethan.., use two lines for their playlist.
      puts "Got it!! #{songs[i-1]} and #{songs[i]}"
      songs[i-1] += songs[i] rescue nil
      songs[i] = nil
    end
    i+=1
  end
  songs.compact
end

def get_spotify_url_from_song(song)
  s = Song.where(:song_name => song)
  if songrecord = s.first
    if songrecord.spotify_id == 'notfound'
      return nil
    else
      return songrecord.spotify_id
    end
  else
    url = "http://ws.spotify.com/search/1/track.json?q=#{URI::encode(song)}"
    begin
      res = JSON.parse(open(url).read)
      songrecord = s.new
      if res["tracks"] && r = res["tracks"].first
        songrecord.spotify_id = r["href"].split(":").last
        songrecord.save!
        return songrecord.spotify_id
      else
        songrecord.spotify_id = 'notfound'
        songrecord.save!
        return nil
      end
    rescue Exception => e
      puts e.inspect
    end
  end
end

def get_playlist_url(djpage)
  songs = get_songs_from_djpage(djpage)
  playlist_url = "https://embed.spotify.com/?uri=spotify:trackset:bFMonSpotify:"

  while(playlist_url.length < 1700 && songs.length > 0)
    s = songs.shift
    url = get_spotify_url_from_song(s)
    if url
      @topsongs[url] ||= 0
      @topsongs[url] += 1
      playlist_url += url + ","
    end
  end
  playlist_url
end

url = "http://www.95bfm.com/default,204025,arcade-djs.sm"
doc = Nokogiri::HTML(open(url))

djs = doc.at_css("div#djlist ul").children.map do |c|
  [c.children.first.text, c.children.first.attributes["href"].value] rescue nil
end.compact

File.open("_includes/playlists.html", "w") do |f|
  djs.each do |d|
    puts "DJ: #{d[0]}"
    url = "http://www.95bfm.com#{d[1]}"
    begin
      djpage = Nokogiri::HTML(open(url))
      playlist_url = get_playlist_url(djpage)
      f.write("<li><a target=\"_blank\" href=\"#{playlist_url}\">#{d[0]}</a> (<a href=\"#{url}\">@bfm</a>)</li>\n")
    rescue Exception => e
      puts "Error with DJ page #{d[0]} - #{d[1]} #{e.inspect}"
    end
    f.flush # 
  end
end

File.open("_includes/toptracks.html", "w") do |f|
  @topsongs.sort_by{|k,v| v}.reverse[0..15].each do |k,v|
    f.write <<-EOF
    <li><iframe src="https://embed.spotify.com/?uri=spotify:track:#{k}" width="300" height="80" frameborder="0" allowtransparency="true"></iframe></li>
    EOF
  end
end