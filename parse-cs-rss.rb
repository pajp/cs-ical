#!/usr/bin/ruby

require 'rubygems'
require 'feed_tools'
require 'digest/md5'
require 'icalendar'
require 'date'
require 'net/http'
require 'uri' 
I_KNOW_I_AM_USING_AN_OLD_AND_BUGGY_VERSION_OF_LIBXML2 = 1
require 'nokogiri'

puts "Downloading CS RSS feed..."
feed = FeedTools::Feed.open("http://www.couchsurfing.org/feeds/event_rss.php?ctid=6082864")
puts "OK"
cal = Icalendar::Calendar.new
cal.custom_property("METHOD","PUBLISH")
feed.items.reverse.each do |item|
  puts "---------------------------------------------------"
  event = Icalendar::Event.new

  event.url=item.link
  event.uid=Digest::MD5.hexdigest("#{item.title} #{item.link}")
  event.dtstart = item.time.strftime("%Y%m%dT%H%M%S")
  puts "Event start: #{event.dtstart}"
  puts "Downloading event #{item.title.to_s} from #{event.url}"
  data = Net::HTTP.get URI.parse(event.url)
  #puts "Downloaded"
  doc = Nokogiri::HTML(data)
  #puts "Parsed"
  next_is_end_date = false
  next_is_date = false
  doc.xpath('//tr/td').each do | stuff |
    foo = stuff.text.chop.chop.strip
    if next_is_date 
      if stuff.text =~ /.* to \d+:\d+ [ap]m/
        to_time = stuff.text.strip.split(" to ")[1]
        puts "Start time has 'to' time: #{to_time}"
        start_date_obj = DateTime::strptime(event.dtstart, "%Y%m%dT%H%M%S")
        end_date_str = start_date_obj.strftime("%B %d, %Y " + to_time)
        puts "end_date_str: #{end_date_str}"
        end_date_obj = DateTime::strptime(end_date_str, "%B %d, %Y %I:%M %p")
        event.dtend = end_date_obj.strftime("%Y%m%dT%H%M%S")
        #end_date += 
      end
      next_is_date = false
    end


    if next_is_end_date
      foo = stuff.text.gsub("th", "").gsub("rd", "").gsub("       - ", " ")
      foo = foo.gsub(/ (\d):(\d\d)/, ' 0\1:\2')
      end_date = foo
      puts "Got end date: \"#{end_date}\""
      date_obj = DateTime::strptime(end_date, "%B %d, %Y %I:%M %p")
      puts "obj: #{date_obj.strftime("%Y%m%dT%H%M%S")}"
      event.dtend = date_obj.strftime("%Y%m%dT%H%M%S")
      next_is_end_date = false

    end
    if foo == "End:"
      next_is_end_date = true
    elsif foo.chop.chop == "Date:"
      next_is_date = true
    end
    #puts "____[[#{foo}]]____"
  end
  if not event.dtend
    event.dtend = item.time.strftime("%Y%m%dT%H%M%S")
  end
  puts "Event end: #{event.dtend}"
  event.summary = item.title.to_s 
  event.description = item.description.to_s
  event.klass = "PUBLIC" 
  cal.add_event(event)
end
ical= cal.to_ical
f=File.open("./cs-helsinki.ics","w")
f.write(ical)
