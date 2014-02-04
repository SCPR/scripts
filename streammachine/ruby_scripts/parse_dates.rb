#!/usr/bin/ruby

require 'date'
require 'json'
require 'csv'

load 'ruby_scripts/apps.rb'

# The number of seconds each app listened
# Key is the name of the app (above)
# Value is the seconds
TIME_FOR_APP = {}

# Bootstrap it with 0 for each app defined above
# Plus add a TOTAL count
APPS.each { |a| TIME_FOR_APP[a[1]] = 0 }
TIME_FOR_APP[:TOTAL] = 0

dates = {}

ARGV.each do |file|
  CSV.foreach(file, headers: :first_row, encoding: "ASCII-8BIT") do |row|
    start   = Time.at(row["Date"].to_i)
    secs    = row["Seconds"].to_i

    # see if some of this listen should be counted toward the following day
    remain = (start.to_date + 1).to_time - start

    splits = []
    if secs > remain
      # yes, split across two days
      splits << [start.to_date, remain]
      splits << [start.to_date + 1, secs - remain]
    else
      # nope, just one day
      splits << [start.to_date,secs]
    end

    splits.each do |part|
      # make sure data structure is set
      date_key = part[0].strftime("%F")
      dates[date_key] ||= TIME_FOR_APP.dup

      APPS.each do |app|
        if row["Player Ident"] =~ Regexp.new(app[0], true) # case-insensitive
          dates[date_key][app[1]] += part[1]
          break
        end
      end

      dates[date_key][:TOTAL] += part[1]
    end
  end
end

CSV($stdout, headers: ["Date", "Total", *TITLES], write_headers: true) do |csv|
  dates.each do |date,times|
    csv << [date, times[:TOTAL], *TITLES.map { |t| times[t] }]
  end
end
