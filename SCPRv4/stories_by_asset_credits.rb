#!/usr/bin/env ruby
# encoding: utf-8

SCRIPT = "stories_by_asset_credits"
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
  opts.banner = "Get a list of stories by their asset credits.\n" \
                "Output files are placed in the Rails " \
                "project's log directory.\n" \
                "Usage: ./stories_by_asset_credits.rb [options]"

  opts.on('-c', '--classes [CLASSES]',
    "A comma-separated list of classes through which to search. " \
    "(default: #{options.classes.join(',')}"
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

  opts.on('-m', '--mode [MODE]',
    "The mode with which to open the file. (default: #{options.filemode})"
  ) do |mode|
    options.filemode = mode
  end

  opts.on('-e', '--headers [HEADERS]',
    "A boolean for whether or not to include headers in the CSV. " \
    "(default: #{options.headers})"
  ) do |headers|
    options.headers = %w{1 true}.include?(headers)
  end

  opts.on_tail('-h', '--help',
    "Show this message."
  ) do
    puts opts
    exit
  end
end.parse!(ARGV)



byline_regex = /^(?<name>.+?) \: (?<start>[\d-]+) - (?<end>[\d-]+)$/

withbio = <<-EOS
Mae Ryan : 2013-06-01 - 2013-08-31
Maya Sugarman : 2013-06-01 - 2013-08-31
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


# With Bio
user_ranges   = []
withbio.split("\n").each do |row|
  user_range = {}

  match = row.match(byline_regex)

  user_range[:user]  = Bio.find_by_name!(match[:name])
  user_range[:low]   = Time.parse(match[:start]).beginning_of_day
  user_range[:high]  = Time.parse(match[:end]).end_of_day

  user_ranges << user_range
end



rows = []

user_ranges.each do |range|
  options.classes.each do |klass|
    klass.constantize.published
    .where(published_at: range[:low]..range[:high])
    .includes(:assets)
    .find_in_batches do |group|
      group.select { |article|
        article.assets.any? { |asset|
          asset.owner && asset.owner.match(range[:user].name)
        }
      }
      .each do |article|
        rows << [
          article.published_at,
          article.to_title,
          article.public_url,
          range[:user].name
        ]
      end
    end
  end
end


#----------------------------
#----------------------------

filename = options.filename || "#{options.fileprefix}-#{Time.now.strftime("%F")}.csv"
filepath = Rails.root.join("log", filename)
CSV.open(filepath, options.filemode, headers: options.headers) do |csv|
  csv << headers if options.headers

  rows.each do |row|
    csv << row
  end
end

puts "Finished. Saved to #{filepath}"

GistUpload.handle(filename, File.read(filepath))
