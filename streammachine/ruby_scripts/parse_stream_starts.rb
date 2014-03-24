#!/usr/bin/ruby

require 'time'
require 'json'
require 'csv'

load 'ruby_scripts/apps.rb'

# The number of seconds each app listened
# Key is the name of the app (above)
# Value is the seconds
STARTS_FOR_APP = {}

# Bootstrap it with 0 for each app defined above
# Plus add a TOTAL count
APPS.each { |a| STARTS_FOR_APP[a[1]] = 0 }
STARTS_FOR_APP[:TOTAL] = 0

dates = {}

start_time  = nil
end_time    = nil

if ENV['START'] && ENV['END']
  # START="2014-03-22 02:00" END="2014-03-22 07:00"
  start_time = Time.parse(ENV['START'])
  end_time   = Time.parse(ENV['END'])

  $stderr.puts "Limiting to #{start_time} - #{end_time}"
end

ARGV.each do |file|
  CSV.foreach(file, headers: :first_row, encoding: "ASCII-8BIT") do |row|
    date      = Time.parse(row["Date"])

    if start_time && end_time
      next if date <= start_time || date > end_time
    end

    date_key  = date.strftime("%F")

    dates[date_key] ||= STARTS_FOR_APP.dup

    APPS.each do |app|
      if row["Player Ident"] =~ Regexp.new(app[0], true) # case insensitive
        dates[date_key][app[1]] += 1
        break
      end
    end

    dates[date_key][:TOTAL] += 1
  end
end

CSV($stdout, headers: ["Date", "All", *TITLES], write_headers: true) do |csv|
  dates.each do |date, starts|
    csv << [date, starts[:TOTAL], *TITLES.map { |t| starts[t] }]
  end
end
