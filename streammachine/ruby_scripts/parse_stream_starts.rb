#!/usr/bin/ruby

require 'date'
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

ARGV.each do |file|
  CSV.foreach(file, headers: :first_row, encoding: "ASCII-8BIT") do |row|
    date      = Time.at(row["Date"].to_i)
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
