#!/usr/bin/ruby

require 'date'
require 'json'
require 'csv'
require 'uri'

all_zeros = 0
all_trunc_num = 0
all_trunc_dur = 0
all_streams = 0

ARGV.each do |fname|
  File.open(fname, :encoding => "ASCII-8BIT") do |f|

    filename = "#{fname.split("/").last.split('.').first}-SoundExchange.txt"
    output = File.open(File.join("parsed", filename), "w+")

    streams = {}

    zeros = 0
    trunc_num = 0
    trunc_dur = 0
    imp_duration = 0

    begin
      while l = f.readline()
        values = l.gsub("  "," UNKNOWN ").split(" ")
        next if values.size < 8 # If we can't parse it then don't even try

        ip        = values[0]
        date      = values[1] # "2011-12-31"
        end_time  = values[2] # "01:03:04"
        stream_id = values[3].match(/(\w+)/)[0]
        status    = values[4]
        ua        = URI.decode(values[5])
        bytes     = values[6].to_i
        duration  = values[7].to_i

        if bytes < duration * 7000
          warn "Impossible Duration::: #{bytes} bytes in #{duration} seconds"
          imp_duration += duration
        end

        # skip connections under 60 seconds
        if duration < 60
          zeros += 1
          next
        end

        # truncate long connections at 24 hours
        if duration > 60*60*24
          warn "Truncating 24-hour stream from #{duration/60/60}"

          trunc_num += 1
          trunc_dur += duration - 60*60*24

          duration = 60*60*24
        end

        # parse date and subtract listened seconds
        time = (DateTime.strptime("#{date} #{end_time}","%F %T").to_time.utc - duration).strftime("%T")
        line = "#{ip}\t#{date}\t#{time}\t#{stream_id}\t#{duration}\t#{status}\t#{ua}\n"
        output << line
      end
    rescue EOFError
      # done!
    end

    output.close

    warn "Ended file with #{streams.length} open streams"
    warn "#{zeros} connections less than 60 seconds"
    warn "Truncated #{trunc_num} connections longer than 24hours. Truncated #{trunc_dur/60/60} hours."
    warn "Impossible seconds: #{imp_duration}"

    all_trunc_num += trunc_num
    all_trunc_dur += trunc_dur
    all_streams += streams.length
    all_zeros += zeros
  end
end


warn "All: Ended with #{all_streams} open streams"
warn "All: #{all_zeros} connections less than 60 seconds"
warn "All: Truncated #{all_trunc_num} connections longer than 24hours. Truncated #{all_trunc_dur/60/60} hours."
