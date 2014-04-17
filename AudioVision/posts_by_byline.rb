#!/usr/bin/env ruby
# encoding: utf-8

SCRIPT = "posts_by_byline"
APP = 'audiovision'

load File.expand_path("../../util/setup.rb", __FILE__)

require "csv"
require 'time'
require 'optparse'
require 'ostruct'

options = OpenStruct.new

# Defaults
options.fileprefix  = SCRIPT
options.filemode    = "w+"
options.headers     = true
options.datafile    = File.expand_path("../data/names.txt", __FILE__)

OptionParser.new do |opts|
  opts.banner = "Get a list of posts by their byline.\n" \
                "Output files are placed in the Rails " \
                "project's log directory.\n" \
                "Usage: ./posts_by_byline.rb [options]"

  opts.on('-p', '--prefix [PREFIX]',
    "The filename prefix. (default '#{options.fileprefix}')"
  ) do |prefix|
    options.fileprefix = prefix
  end

  opts.on('-f', '--filename [FILENAME]',
    "The filename to output to. This overrides the prefix option."
  ) do |filename|
    options.filename = filename
  end

  opts.on('-d', '--data [FILENAME]',
    "The filename containing the data to parse. (default: data/names.txt)"
  ) do |datafile|
    options.datafile = datafile
  end

  opts.on('-e', '--headers [HEADERS]',
    "A boolean for whether or not to include headers in the CSV. " \
    "(default: #{options.headers})"
  ) do |headers|
    options.headers = %w{1 true}.include?(headers)
  end

  opts.on('-m', '--mode [MODE]',
    "The mode with which to open the file. (default: #{options.filemode})"
  ) do |mode|
    options.filemode = mode
  end

  opts.on_tail('-h', '--help',
    "Show this message."
  ) do
    puts opts
    exit
  end
end.parse!(ARGV)



byline_regex = /^(?<name>.+?) : (?<start>[\d-]+) - (?<end>[\d-]+)$/

names = File.open(options.datafile)

headers = [
  "Publish Date",
  "Title",
  "URL",
  "Reporter"
]


#----------------------------
#----------------------------

puts "Generating CSV..."

rows = []

names.each do |row|
  next if row.empty?

  match = row.match(byline_regex)

  if !match
    raise "No match for '#{row}'. Check format."
  end

  name   = match[:name]
  low    = Time.parse(match[:start]).beginning_of_day
  high   = Time.parse(match[:end]).end_of_day


  attributions = Attribution.where('name like ?', "%#{name}%").to_a

  # If there is a bio for this name, add in that bio's bylines
  if reporter = Reporter.find_by_name(name)
    attributions += reporter.attributions.to_a
  end

  attributions.select { |b|
    b.post.published? &&
    b.post.published_at.between?(low, high)
  }
  .sort { |a,b| b.created_at <=> a.created_at }
  .each do |attribution|
    post = attribution.post

    rows << [
      post.published_at,
      post.to_title,
      post.public_url,
      name
    ]
  end
end


#----------------------------
#----------------------------

filename = options.filename ||
  "#{options.fileprefix}-#{Time.now.strftime("%F")}.csv"

filepath = File.expand_path("../log/#{filename}", __FILE__)

CSV.open(filepath, options.filemode, headers: options.headers) do |csv|
  csv << headers if options.headers

  rows.each do |row|
    csv << row
  end
end

puts "Finished. Saved to #{filepath}"

GistUpload.handle(filename, File.read(filepath))
