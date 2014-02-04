#!/usr/bin/ruby

require 'apachelogregex'
require 'date'
require 'json'

oformat = '%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"'
format = '%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %O'
# 64.55.111.113 - - [30/Jun/2011:00:01:04 -0700] "GET /law HTTP/1.1" 200 25772 "-" "Mozilla/5.0 (Linux; U; Windows NT 6.1; en-us; dream) DoggCatcher" 25985

oparser = ApacheLogRegex.new(oformat)
parser = ApacheLogRegex.new(format)

by_day = {}
by_month = {}
totals = {}

SHOWS = [
  'airtalk',
  'askthechief',
  'bmoc',
  'comedycongress',
  'cyberfrequencies',
  'dpd',
  'eatla',
  'events',
  'features',
  'filmweek',
  'haefele',
  'lacter',
  'latw',
  'ldos',
  'loh',
  'marquee',
  'mbrand',
  'newscast',
  'offramp',
  'pacificdrift',
  'pattmorrison',
  'prepend',
  'storycorps',
  'streetstories',
  'taketwo',
  'titlewave',
  'townhalljournal'
]

# populate hashes
[SHOWS,'segments','other'].flatten.each {|k| by_day[k] = {}; by_month[k] = {}; totals[k] = 0 } 

# build regex
REGEX = Regexp.new("GET /(audio|podcasts)/(" + SHOWS.map {|k| k }.join('|') + ").*\.mp3\s")

$stderr.puts("REGEX is #{REGEX}")

ips = {}

File.open(ARGV[0]) do |f|
  begin 
    while l = f.readline()
      # don't bother parsing non-mp3 lines
      if l !~ /mp3/
        next
      end
      
      data = parser.parse(l)
      
      if !data
        data = oparser.parse(l)
      end
            
      if data
        # skip non-200 responses
        if data['%>s'] !~ /20[06]/ || data['%r'] !~ /^GET/
          next
        end

        # parse date
        date = DateTime.strptime(data['%t'],"[%d/%b/%Y:%H:%M:%S %z]")
        
        if data['%>s'] == '206'
          ip = data['%h']
          
          if !ips[ ip ]
            ips[ ip ] = {}
          end
          
          if !ips[ ip ][ data['%r'] ]
            # first hit...  count it
            ips[ ip ][ data['%r'] ] = date
          else
            if ips[ ip ][ data['%r'] ] >= (date - (60*30))
              # hit within last 30 minutes...  pass
              next
            else
              ips[ ip ][ data['%r'] ] = date
            end
          end
        end
        
        day_key = [date.year,date.month,date.day].join("-")
        mon_key = [date.year,date.month].join("-")
        
        # look for show files
        if data['%r'] =~ REGEX
          show = $~[2]
        
          # what type of access is this?
          data['%r'] =~ /GET \/(podcasts|audio)\//
        
          type = ($~ && $~[1] == "podcasts") ? :podcast : :ondemand
        
          # add to month and day stats
          if !by_day[show][day_key]
            by_day[show][day_key] = { :podcast => 0, :ondemand => 0 }
          end
        
          by_day[show][day_key][type] += 1
        
          if !by_month[show][mon_key]
            by_month[show][mon_key] = { :podcast => 0, :ondemand => 0 }
          end
        
          by_month[show][mon_key][type] += 1
          
          totals[show] += 1
        else
          key = (data['%r'] =~ /audio\/upload/) ? 'segments' : 'other'
          
          if !by_day[key][day_key]
            by_day[key][day_key] = { :ondemand => 1 }
          else
            by_day[key][day_key][:ondemand] += 1
          end
          
          if !by_month[key][mon_key]
            by_month[key][mon_key] = { :ondemand => 1 }
          else
            by_month[key][mon_key][:ondemand] += 1
          end
          
          totals[key] += 1
          
          if key == 'other'
            #$stderr.puts data
          end
        end
        
        # status
        #if i%100 == true
        #  $stderr.puts [SHOWS,'segments','other'].flatten.map { |k| totals[k] }.join("\t")
        #end
        
        #i += 1
      end
    end
  rescue EOFError
    # done!
  end
end

puts by_month.to_json
puts by_day.to_json
