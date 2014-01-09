#!/usr/bin/env ruby

SCRIPT = "editions"
APP = 'scprv4'

load File.expand_path("../../util/setup.rb", __FILE__)

require "csv"
require 'time'
require 'optparse'
require 'ostruct'
require 'net/http'
require 'uri'

options = OpenStruct.new

# Defaults
options.fileprefix  = SCRIPT
options.upper       = Time.now


OptionParser.new do |opts|
  opts.banner = "Get a list of editions."\
                "Output files are placed in the Rails " \
                "project's log directory.\n" \
                "Usage: ruby editions.rb [options]"

  opts.on('-l', '--lower LOWER',
    "Beginning of date range, in ISO-format (YYYY-MM-DD). Time is assumed " \
    "to be midnight."
  ) do |lower|
    options.lower = Time.parse(lower)
  end

  opts.on('-u', '--upper [UPPER]',
    "End of date range, in ISO-format (YYYY-MM-DD). Time is assumed to be " \
    "midnight. (default: now)."
  ) do |upper|
    options.upper = Time.parse(upper)
  end

  opts.on('-p', '--prefix [PREFIX]',
    "The filename prefix. (default 'editions')"
  ) do |prefix|
    options.fileprefix = prefix
  end

  opts.on_tail('-h', '--help',
    "Show this message."
  ) do
    puts opts
    exit
  end
end.parse!(ARGV)



rows = []

puts "Generating CSV..."

condition_string = ""
condition_string += "published_at > :low and " if options.lower
condition_string +=  "published_at <= :high"

Edition.where(condition_string,
  :low    => options.lower,
  :high   => options.upper
).published.reorder("published_at").each do |edition|
  rows.push [
    edition.id,
    edition.title,
    edition.published_at,
    edition.abstracts.count
  ]
end

filename = "#{options.fileprefix}-#{Time.now.strftime("%F")}.csv"
filepath = Rails.root.join("log", filename)
CSV.open(filepath, "w+", headers: true) do |csv|
    csv << [
    "ID",
    "Title",
    "Publish Timestamp",
    "# Abstracts"
  ]

  rows.each do |row|
    csv << row
  end
end

puts "Finished. Saved to #{filepath}"

GistUpload.handle(filename, File.read(filepath))
