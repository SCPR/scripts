#!/usr/bin/ruby

require 'apachelogregex'
require 'date'
require 'json'
require 'csv'
require 'uri'

# Constants to help the GC out.
C = {
  :mp3_re           => /mp3/,
  :request_re       => /GET (?<path>.+?)\s/,
  :podcast_re       => /\/podcasts\//,
  :audio_re         => /\/audio\//,
  :amp_re           => /&amp;/,
  :media_url        => "http://media.scpr.org",
  :status_partial   => '206',
  :allowed_status   => ['200', '206'],
  :date_format      => "[%d/%b/%Y:%H:%M:%S %z]",
  :data_status      => '%>s',
  :data_ip          => '%h',
  :data_req         => '%r',
  :data_date        => '%t',
  :data_ua          => '%{User-Agent}i',
  :data_referer     => '%{Referer}i',
  :amp              => '&',
  :eq               => '=',
  :mobile_ua        => /(Android|iPad|iPhone)/,
  :via              => "via",
  :source           => "source",
  :context          => "context",
  :podcast          => "podcast",
  :website          => "website",
  :api              => "api",
  :scpr_org         => "www.scpr.org",
  :unknown          => "unknown"
}

# For the numbers CSV, we want to restrict the sources to just these few.
ALLOWED_SOURCES = %w{ podcast api website unknown rss }

# We still need to load these for the fallback context inference.
SHOWS = File.open("shows.txt").each_line.map { |l| l.chomp("\n") }.reject(&:empty?)
all_contexts = {}

# We want to keep track of partial requests so we don't log them multiple times
partial_requests = {}

# 64.55.111.113 - - [30/Jun/2011:00:01:04 -0700] "GET /law HTTP/1.1" 200 \
# 25772 "-" "Mozilla/5.0 (Linux; U; Windows NT 6.1; en-us; dream) DoggCatcher"
format = '%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"'
parser = ApacheLogRegex.new(format)

fn_date = "#{Time.now.year}-#{Time.now.month - 1}"
output = CSV.open(
  File.join("parsed", "audio-requests-#{fn_date}.csv"), "w",
  :headers => ["Audio Source", "Audio Context"],
  :write_headers => true
)

failure_output = CSV.open(
  File.join("logs", "failures.csv"), "w",
  :headers => ["Missing Info", "Log line"],
  :write_headers => true
)

File.open(ARGV[0]).each_line do |line|
  # don't bother parsing non-mp3 lines
  next if line !~ C[:mp3_re]

  # Extract the request information from the log line.
  # If the line can't be parsed by apachelogregex, move on.
  data = parser.parse(line)
  next if !data

  log_status    = data[C[:data_status]]
  log_ip        = data[C[:data_ip]]
  log_request   = data[C[:data_req]]
  log_date      = data[C[:data_date]]
  log_ua        = data[C[:data_ua]]
  log_referer   = data[C[:data_referer]]

  # skip non-200/206 responses or non-GET requests
  next unless C[:allowed_status].include?(log_status)

  # Match the request to extract the path (and make sure it's valid)
  match = log_request.match(C[:request_re])
  next if !match

  # parse date
  date = DateTime.strptime(log_date, C[:date_format])

  # For partial content, we don't want to count each request as a
  # separate logged listen, so we'll only log it once every 30 minutes.
  if log_status == C[:status_partial]
    partial_requests[log_ip] ||= {}

    if partial_requests[log_ip][log_request] &&
    partial_requests[log_ip][log_request] >= (date - (60*30))
      # hit within last 30 minutes...  pass
      next
    else
      # first hit...  count it
      partial_requests[log_ip][log_request] = date
    end
  end

  # Get the URI. We need to append the media URL to it for reliable parsing.
  uri_str = "#{C[:media_url]}#{match[:path]}"
  uri = URI.parse(uri_str)
  source, context = nil

  # If this URL had a query string, then parse it out to extract source/context.
  if uri.query
    uri.query.gsub!(C[:amp_re], C[:amp])

    params = uri.query.split(C[:amp]).map { |p|
      p.split(C[:eq])
    }.reduce({}) { |hsh, p|
      hsh.merge!(p[0] => p[1])
    }

    source  = params[C[:via]]     # website, podcast, api, etc.
    context = params[C[:context]] # airtalk, offramp, etc.
  end

  # Try to infer the source from the log line if it wasn't set by params
  if !source
    # If this was a request to /podcasts/, then set the source to "podcast"
    # If not, then we need to try to figure out where it's coming from
    # based on the user-agent.
    if uri_str.match(C[:podcast_re])
      source = C[:podcast]
    elsif uri_str.match(C[:audio_re])
      # If this was from a mobile something, mark it as an API request.
      if log_ua.match(C[:mobile_ua])
        source = C[:api]
      else
        # It was *probably* the website if we got here.
        # If not, we should count it anyways.
        if log_referer.match(C[:scpr_org])
          source = C[:website]
        end
      end
    end
  end


  # Try to infer the context from the log line if it wasn't set by params
  if !context
    # Search the log line for anything matching one of our shows.
    context = SHOWS.find { |s| line.match(s) }
  end


  # Finally, just mark them as "unknown" if we can't infer anything.
  # Log these unknown entries to logs/failures.csv with the log line.
  if !source
    failure_output << [C[:source], line]
    source = C[:unknown]
  end

  if !context
    failure_output << [C[:context], line]
    context = C[:unknown]
  end

  # Log numbers
  all_contexts[context] ||= {}
  all_contexts[context][source] ||= 0
  all_contexts[context][source] += 1

  # Write to CSV
  # output << [source, context]
end

# Close our IO
output.close
failure_output.close


# Write final numbers.
all_sources = all_contexts.values.map(&:keys).flatten.uniq.select { |s|
  ALLOWED_SOURCES.include? s
}

final_nums = CSV.open(
  File.join("parsed", "numbers-#{fn_date}.csv"), "w",
  :headers => ["Context", *all_sources],
  :write_headers => true
) do |csv|
  all_contexts.each do |context, source_counts|
    csv << [context, *all_sources.map { |s| source_counts[s] || 0 }]
  end
end
