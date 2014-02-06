#!/usr/bin/env ruby
# encoding: utf-8

SCRIPT = "stories_with_category"
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
options.limit       = 300
options.filemode    = "w+"
options.headers     = true

OptionParser.new do |opts|
  opts.banner = "Get a list of n recent stories with a category.\n" \
                "Output files are placed in the Rails " \
                "project's log directory.\n" \
                "Usage: ./stories_with_category.rb [options]"

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
    "The filename to output to. This overrides the prefix option."
  ) do |filename|
    options.filename = filename
  end

  opts.on('-l', '--limit [LIMIT]',
    "An integer of the number of recent stories to fetch. " \
    "(default: #{options.limit})"
  ) do |limit|
    options.limit = limit.to_i
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



headers = [
  "Category",
  "Title",
  "URL",
  "Publish Date",
]


#----------------------------
#----------------------------

puts "Generating CSV..."

rows = []

options.classes.map(&:constantize).each do |klass|
  klass.published.limit(options.limit).where('category_id is not null').each do |article|
    rows << [
      article.category.title,
      article.headline,
      article.public_url,
      article.published_at
    ]
  end
end

rows = rows.sort { |a, b| b[3] <=> a[3] }.first(300)

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
