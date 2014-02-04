#!/usr/bin/ruby

require 'apachelogregex'
require 'date'
require 'json'

oformat = '%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"'
format  = '%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %O'
# 64.55.111.113 - - [30/Jun/2011:00:01:04 -0700] "GET /law HTTP/1.1" 200 25772 "-" "Mozilla/5.0 (Linux; U; Windows NT 6.1; en-us; dream) DoggCatcher" 25985

oparser = ApacheLogRegex.new(oformat)
parser = ApacheLogRegex.new(format)

by_day            = {}
by_month          = {}
totals            = {}
partial_requests  = {}

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
[SHOWS,'segments','other'].flatten.each do |k|
  by_day[k]     = {}
  by_month[k]   = {}
  totals[k]     = 0
end

# build regex
REGEX = Regexp.new("GET /(audio|podcasts)/(" + SHOWS.join('|') + ").*\.mp3\s")

$stderr.puts("REGEX is #{REGEX}")

File.open(ARGV[0]) do |f|
  begin
    while l = f.readline()
      # don't bother parsing non-mp3 lines
      next if l !~ /mp3/

      data = parser.parse(l)

      if !data
        puts "Using oparser"
        data = oparser.parse(l)
      end

      next if !data

      log_status    = data['%>s']
      log_ip        = data['%h']
      log_request   = data['%r']
      log_date      = data['%t']

      # skip non-200/206 responses or non-GET requests
      next if log_status !~ /20[06]/ || log_request !~ /^GET/

      # parse date
      date = DateTime.strptime(log_date, "[%d/%b/%Y:%H:%M:%S %z]")

      # For partial content, we don't want to count each request as a
      # separate logged listen, so we'll only log it once every 30 minutes.
      if log_status == '206'
        partial_requests[log_ip] ||= {}

        if partial_requests[ip][request] &&
        partial_requests[ip][request] >= (date - (60*30))
          # hit within last 30 minutes...  pass
          next
        else
          # first hit...  count it
          partial_requests[ip][request] = date
        end
      end

      day_key = [date.year, date.month, date.day].join("-")
      mon_key = [date.year, date.month].join("-")

      # look for show files
      if request =~ REGEX
        show = $~[2]

        # what type of access is this?
        requested_type = request.match(/GET \/(podcasts|audio)\//)[1]
        type = (requested_type == "podcasts") ? :podcast : :ondemand

        # add to month and day stats
        by_day[show][day_key] ||= { podcast: 0, ondemand: 0 }
        by_month[show][mon_key] ||= { :podcast => 0, :ondemand => 0 }

        by_day[show][day_key][type] += 1
        by_month[show][mon_key][type] += 1

        totals[show] += 1

      else
        key = (request =~ /audio\/upload/) ? 'segments' : 'other'

        by_day[key][day_key] ||= { ondemand: 0 }
        by_month[key][mon_key] ||= { ondemand: 0 }

        by_day[key][day_key][:ondemand] += 1
        by_month[key][mon_key][:ondemand] += 1

        totals[key] += 1
      end
    end
  rescue EOFError
    # done!
  end
end

puts by_month.to_json
puts by_day.to_json
