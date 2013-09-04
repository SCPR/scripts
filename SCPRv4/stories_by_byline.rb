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

OptionParser.new do |opts|
  opts.banner = "Get a list of stories by their byline.\n" \
                "Output files are placed in the Rails " \
                "project's log directory.\n" \
                "Usage: ./stories_by_byline.rb [options]"

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

  opts.on_tail('-h', '--help',
    "Show this message."
  ) do
    puts opts
    exit
  end
end.parse!(ARGV)



byline_regex = /^(?<name>.+?) \: (?<start>[\d-]+) - (?<end>[\d-]+)$/

normal_withbio = <<-EOS
Erika Aguilar : 2013-06-01 - 2013-08-31
Leslie Berestein Rojas : 2013-06-01 - 2013-08-31
Adolfo Guzman-Lopez : 2013-06-01 - 2013-08-31
Rina Palta : 2013-06-01 - 2013-08-31
Jose Luis Jiménez : 2013-06-01 - 2013-08-31
Evelyn Larrubia : 2013-06-01 - 2013-08-31
Ashley Alvarado : 2013-06-01 - 2013-08-31
Michelle Lanz : 2013-06-01 - 2013-08-31
Jon White : 2013-06-01 - 2013-08-31
EOS

normal_nobio = <<-EOS
Annie Gilbertson : 2013-08-12 - 2013-08-31
Jed Kim : 2013-06-01 - 2013-08-31
Gordon Henderson : 2013-07-01 - 2013-08-31
Kristen Lepore : 2013-06-01 - 2013-08-31
Steve Martin : 2013-06-01 - 2013-08-30
EOS

taketwo_withbio = <<-EOS
A Martínez : 2013-06-01 - 2013-08-31
Leo Duran : 2013-06-01 - 2013-08-31
Josie Huang : 2013-06-01 - 2013-08-31
Laura Krantz : 2013-06-01 - 2013-08-31
Jacob Margolis : 2013-06-01 - 2013-08-31
EOS

taketwo_nobio = <<-EOS
Stephen Hoffman : 2013-06-01 - 2013-08-31
EOS

headers = [
  "Publish Date",
  "Title",
  "URL",
  "Byline"
]


#----------------------------
#----------------------------

puts "Generating CSV..."


# With Bio
user_ranges   = []
normal_withbio.split("\n").each do |row|
  user_range = {}

  match = row.match(byline_regex)

  user_range[:user]  = Bio.find_by_name!(match[:name])
  user_range[:low]   = Time.parse(match[:start]).beginning_of_day
  user_range[:high]  = Time.parse(match[:end]).end_of_day

  user_ranges << user_range
end

# Without Bio
nobio_ranges = []
normal_nobio.split("\n").each do |row|
  user_range = {}
  match = row.match(byline_regex)

  user_range[:name]  = match[:name]
  user_range[:low]   = Time.parse(match[:start]).beginning_of_day
  user_range[:high]  = Time.parse(match[:end]).end_of_day

  nobio_ranges << user_range
end

# Take Two with Bio
taketwo_withbio_ranges = []
taketwo_withbio.split("\n").each do |row|
  user_range = {}
  match = row.match(byline_regex)

  user_range[:user]  = Bio.find_by_name!(match[:name])
  user_range[:low]   = Time.parse(match[:start]).beginning_of_day
  user_range[:high]  = Time.parse(match[:end]).end_of_day

  taketwo_withbio_ranges << user_range
end

# Take Two without Bio
taketwo_nobio_ranges = []
taketwo_nobio.split("\n").each do |row|
  user_range = {}
  match = row.match(byline_regex)

  user_range[:name]  = match[:name]
  user_range[:low]   = Time.parse(match[:start]).beginning_of_day
  user_range[:high]  = Time.parse(match[:end]).end_of_day

  taketwo_nobio_ranges << user_range
end



rows = []

user_ranges.each do |range|
  range[:user].bylines
  .where(content_type: options.classes)
  .select { |b|
    b.content.published? &&
    b.content.published_at.between?(range[:low], range[:high])
  }
  .each do |byline|
    content = byline.content

    rows << [
      content.published_at,
      content.to_title,
      content.public_url,
      content.byline
    ]
  end
end

nobio_ranges.each do |range|
  ContentByline.where('name like ?', "%#{range[:name]}%")
  .where(content_type: options.classes)
  .select { |b|
    b.content.published? &&
    b.content.published_at.between?(range[:low], range[:high])
  }
  .each do |byline|
    content = byline.content

    rows << [
      content.published_at,
      content.to_title,
      content.public_url,
      content.byline
    ]
  end
end

taketwo_withbio_ranges.each do |range|
  range[:user].bylines
  .where(content_type: options.classes)
  .reject { |b|
    b.content.is_a?(ShowSegment) &&
    b.content.show.slug == "take-two"
  }
  .select { |b|
    b.content.published? &&
    b.content.published_at.between?(range[:low], range[:high])
  }
  .each do |byline|
    content = byline.content

    rows << [
      content.published_at,
      content.to_title,
      content.public_url,
      content.byline
    ]
  end
end

taketwo_nobio_ranges.each do |range|
  ContentByline.where('name like ?', "%#{range[:name]}%")
  .where(content_type: options.classes)
  .reject { |b|
    b.content.is_a?(ShowSegment) &&
    b.content.show.slug == "take-two"
  }
  .select { |b|
    b.content.published? &&
    b.content.published_at.between?(range[:low], range[:high])
  }
  .each do |byline|
    content = byline.content

    rows << [
      content.published_at,
      content.to_title,
      content.public_url,
      content.byline
    ]
  end
end


#----------------------------
#----------------------------

filename = options.filename || "#{options.fileprefix}-#{Time.now.strftime("%F")}.csv"
filepath = Rails.root.join("log", filename)
CSV.open(filepath, options.filemode, headers: true) do |csv|
  csv << headers

  rows.each do |row|
    csv << row
  end
end

puts "Finished. Saved to #{filepath}"

GistUpload.handle(filename, File.read(filepath))
