#!/usr/bin/env ruby

SCRIPT = "entries_by_blog"
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
  opts.banner = "Get a list of entries for individual blogs within a "\
                "range of dates.\n" \
                "Output files are placed in the Rails " \
                "project's log directory.\n" \
                "Usage: ruby entries_by_blog.rb [options]"

  opts.on('-l', '--lower LOWER',
    "Beginning of date range, in ISO-format (YYYY-MM-DD). Time is assumed " \
    "to be midnight."
  ) do |lower|
    options.lower = Time.parse(lower)
  end

  opts.on('-b', '--blogs BLOGS',
    "A comma-separated list of blogs (slugs) on which to perform the task."
  ) do |blogs|
    options.blogs = blogs.split(',')
  end

  opts.on('-u', '--upper [UPPER]',
    "End of date range, in ISO-format (YYYY-MM-DD). Time is assumed to be " \
    "midnight. (default: now)."
  ) do |upper|
    options.upper = Time.parse(upper)
  end

  opts.on('-p', '--prefix [PREFIX]',
    "The filename prefix. (default 'entries_by_blog')"
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

raise(ArgumentError, "At least one blog must be specified.") if !options.blogs
raise(ArgumentError, "The lower date limit must be specified.") if !options.lower



rows = []

puts "Generating CSV..."

options.blogs.each do |blog|
  blog = Blog.find_by_slug!(blog)

  blog.entries.where(
    "published_at > :low and published_at <= :high",
    :low    => options.lower,
    :high   => options.upper
  ).published.reorder("published_at").each do |entry|
    rows.push [
      entry.published_at,
      entry.to_title,
      entry.byline,
      entry.public_url
    ]
  end
end

filename = "#{options.fileprefix}-#{Time.now.strftime("%F")}.csv"
filepath = "output/#{filename}"
CSV.open(filepath, "w+") do |csv|
  rows.each do |row|
    csv << row
  end
end

puts "Finished. Saved to #{filepath}"

GistUpload.handle(filename, File.read(filepath))
