require "rubygems"
require "bundler/setup"
require "rss"
require "open-uri"
require_relative "lib/YAMLCache"

# The purpose of this script is to read the ED Galnet RSS Feed proxy and filter it for new unique entries with more realistic dates based on logging.
# It will generate a new RSS feed that can be used to avoid issues with RSS readers like MonitoRSS for Discord.

# Override to write description with CDATA
class RSS::Rss::Channel::Item
  def description_element need_convert, indent
    markup = "#{indent}<description>"
    markup << "<![CDATA[#{@description}]]>"
    markup << "</description>"
    markup
  end
end

Cache = YAMLCache.new("data/galnet_cache/articles.yml")
Cache.ensureArray("activeGuids")
Cache.ensureHash("knownGuids")

# RSS Maker for our proxy
output = RSS::Maker.make("2.0") do |maker|
  maker.channel.pubDate = Time.now.utc.to_s
  maker.channel.title = "Elite Dangerous Galnet News"
  maker.channel.description = "Rebuilt proxy of the Elite Dangerous Galnet News Feed"
  maker.channel.link = "https://community.elitedangerous.com/galnet-rss"
  maker.channel.language = "en"

  # Read GalNet feed from properly formatted proxy
  URI.open("http://proxy.gonegeeky.com/edproxy/") do |rss|
    feed = RSS::Parser.parse(rss)

    # Filter top 10 unique
    feed.items.uniq! {|x| x.guid.content }.first(10)

    # Get top 10 unique guids from current feed to consider as active if they are known and did not disappear
    validGuids = feed.items.collect {|x| x.guid.content } & Cache["activeGuids"]

    feed.items.each do |article|
      valid = false
      if validGuids.include?(article.guid.content)
        # Known remaining articles are valid and will be proxied
        valid = true
      elsif !Cache["knownGuids"][article.guid.content]
        # Unknown but new article will be added to valid and proxied as well
        valid = true
        validGuids.push(article.guid.content)
        Cache["knownGuids"][article.guid.content] = article.pubDate
      end
      next if !valid
      # Write article into our rebuilt feed
      maker.items.new_item do |item|
        item.guid.isPermaLink = false
        item.guid.content = article.guid.content
        item.link = article.link
        item.title = article.title
        item.description = article.description

        # Do not reuse pub date as it is wrong. Instead use date from when we picked it up first
        item.pubDate = Cache["knownGuids"][article.guid.content]
      end
    end

    Cache["activeGuids"] = validGuids
  end
end

# Write feed
File.write("data/galnet_cache/feed.xml", output, mode: "w:UTF-8")

# Save cache
Cache.save
