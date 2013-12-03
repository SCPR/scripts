#!/usr/bin/env ruby
# encoding: utf-8

SCRIPT = "stories_by_byline"
APP = 'scprv4'

load File.expand_path("../../util/setup.rb", __FILE__)

require "csv"
require 'time'
require 'optparse'
require 'ostruct'

options = OpenStruct.new

# Defaults
options.fileprefix  = SCRIPT
options.classes     = ["NewsStory", "BlogEntry", "ShowSegment"]
options.filemode    = "w+"
options.headers     = true

OptionParser.new do |opts|
  opts.banner = "Get a list of stories by their byline.\n" \
                "Output files are placed in the Rails " \
                "project's log directory.\n" \
                "Usage: ./stories_by_byline.rb [options]"

  opts.on('-c', '--classes [CLASSES]',
    "A comma-separated list of classes through which to search. " \
    "(default: #{options.classes.join(',')})"
  ) do |classes|
    options.classes = classes.split(',')
  end

  opts.on('-p', '--prefix [PREFIX]',
    "The filename prefix. (default '#{options.fileprefix}')"
  ) do |prefix|
    options.fileprefix = prefix
  end

  opts.on('-f', '--filename [FILENAME]',
    "The filename to use. This overrides the prefix option."
  ) do |filename|
    options.filename = filename
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



byline_regex = /^(?<name>.+?) \((?<start>.+?)-(?<end>.+?)\)$/

names = <<-EOS
Erika Aguilar (September 1-November 30)
Leslie Berestein Rojas (September 1-November 30)
Annie Gilbertson (September 1-November 30)
Adolfo Guzman-Lopez (September 1-November 30)
Josie Huang (September 1-November 30)
Jed Kim (September 1-November 30)
Rina Palta (September 1-November 30)
Jose Luis Jiménez (September 1-November 30)
Evelyn Larrubia (September 1-November 30)
Mae Ryan (September 1-November 30)
Maya Sugarman (September 1-November 30)
A Martínez (September 1-November 30)
Leo Duran (September 1-November 30)
Laura Krantz (September 1-November 30)
Jacob Margolis (September 1-November 30)
Ashley Alvarado (September 1-November 30)
Michelle Lanz (September 1-November 30)
Jon White (September 1-November 30)
Stephen Hoffman (September 1-November 30)
Gordon Henderson (September 1-November 30)
Kristen Lepore (September 1-November 30)
EOS

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

names.split("\n").each do |row|
  match = row.match(byline_regex)

  if !match
    raise "No match for '#{row}'. Check format."
  end

  low    = Time.new(2013, 9, 1).beginning_of_day
  high   = Time.new(2013, 11, 30).end_of_day


  bylines = ContentByline.where('name like ?', "%#{match[:name]}%")
    .where(content_type: options.classes).to_a

  # If there is a bio for this name, add in that bio's bylines
  if bio = Bio.find_by_name(match[:name])
    bylines += bio.bylines
      .where(content_type: options.classes).to_a
  end

  bylines.select { |b|
    b.content.published? &&
    b.content.published_at.between?(low, high)
  }
  .sort { |a,b| b.created_at <=> a.created_at }
  .each do |byline|
    content = byline.content

    rows << [
      content.published_at,
      content.to_title,
      content.public_url,
      match[:name]
    ]
  end
end


#----------------------------
#----------------------------

filename = options.filename ||
  "#{options.fileprefix}-#{Time.now.strftime("%F")}.csv"

filepath = Rails.root.join("log", filename)

CSV.open(filepath, options.filemode, headers: options.headers) do |csv|
  csv << headers if options.headers

  rows.each do |row|
    csv << row
  end
end

puts "Finished. Saved to #{filepath}"

GistUpload.handle(filename, File.read(filepath))
