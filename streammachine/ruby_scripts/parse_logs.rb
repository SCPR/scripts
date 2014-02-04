#!/usr/bin/ruby

require 'date'
require 'time'
require 'json'
require 'csv'

all_zeros = 0
all_trunc_num = 0
all_trunc_dur = 0
all_streams = 0

CSV($stdout,:headers => ["Date","Seconds","IP Address","Player Ident"],:write_headers => true) do |csv|
  ARGV.each do |fname|
    File.open(fname, :encoding => "ASCII-8BIT") do |f|
      streams = {}

      zeros = 0
      trunc_num = 0
      trunc_dur = 0

      begin
        while l = f.readline()
          if l =~ /^<([^>]+)> \[dest: [\d\.]+\] starting stream \(UID: (\d+)\)\[L: \d+\]\{A: ([^\}]+)\}/
            # store player ident under UID
            streams[$~[2].to_i] = $~[3]
          elsif l =~ /^<([^>]+)> \[dest: ([\d\.]+)\] connection closed \((\d+) seconds\) \(UID: (\d+)\)/
            # now take the UID and seconds, and match it up against the player ident
            secs = $~[3].to_i
            ip = $~[2]

            if secs >= 60
              ident = streams.delete($~[4].to_i)
              #$stderr.puts "stream length is #{streams.length}"

              if secs > 60*60*24
                $stderr.puts "Truncating 24-hour stream from #{secs/60/60}"

                trunc_num += 1
                trunc_dur += secs - 60*60*24

                secs = 60*60*24
              end

              # parse date and subtract listened seconds
              begin
                time = Time.parse($~[1].sub(/^(\d\d)\/(\d\d)\/(\d\d)/,'\\3/\\1/\\2')) - secs
              rescue
                $stderr.puts "Can't parse time: #{$~[1]}"
                exit;
              end

              csv << [time.to_i,secs,ip,ident]
            else
              streams.delete($~[4].to_i)
              zeros += 1
            end
          else

          end
        end
      rescue EOFError
        # done!
      end

      $stderr.puts "Ended file with #{streams.length} open streams"
      $stderr.puts "#{zeros} connections less than 60 seconds"
      $stderr.puts "Truncated #{trunc_num} connections longer than 24hours. Truncated #{trunc_dur/60/60} hours."

      all_trunc_num += trunc_num
      all_trunc_dur += trunc_dur
      all_streams += streams.length
      all_zeros += zeros
    end
  end
end

$stderr.puts "All: Ended with #{all_streams} open streams"
$stderr.puts "All: #{all_zeros} connections less than 60 seconds"
$stderr.puts "All: Truncated #{all_trunc_num} connections longer than 24hours. Truncated #{all_trunc_dur/60/60} hours."
