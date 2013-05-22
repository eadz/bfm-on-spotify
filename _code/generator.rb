require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'json'

def get_songs_from_djpage(djpage)
  songs = djpage.at_css("ul.djextra").children.map{|c| c.text.gsub(/\n|\t/,' ').gsub(/ {1,99}/,' ').strip}.compact
  songs.delete_if{|s| s == ""}
  songs
end

def get_spotify_url_from_song(song)
  url = "http://ws.spotify.com/search/1/track.json?q=#{URI::encode(song)}"
  begin
    res = JSON.parse(open(url).read)
    if res["tracks"] && r = res["tracks"].first
      r["href"]
    end
  rescue Exception => e
    puts e
  end
end

def get_playlist_url(djpage)
  songs = get_songs_from_djpage(djpage)
  playlist_url = "https://embed.spotify.com/?uri=spotify:trackset:bFMonSpotify:"

  while(playlist_url.length < 1900)
    s = songs.shift
    sleep 0.5
    url = get_spotify_url_from_song(s)
    if url
      puts url.split(":").last
      playlist_url += url.split(":").last + ","
    end
  end
  playlist_url
end

url = "http://www.95bfm.com/default,204025,arcade-djs.sm"
doc = Nokogiri::HTML(open(url))


#puts songs

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
      f.write("<li><a target=\"_blank\" href=\"#{playlist_url}\">#{d[0]}</a></li>")
    rescue Exception => e
      puts "Error with DJ page #{d[0]} - #{d[1]}"
    end
  end
end
