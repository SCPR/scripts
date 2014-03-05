SCRIPT = "image-references"
APP = 'scprv4'

load File.expand_path("../../util/setup.rb", __FILE__)

require 'find'
require 'pathname'

##
# Given a directory, loop through all of its files recursively,
# and then search the project for references to each file.
files_base = Rails.root.join("app/assets/images").to_s

# Which paths to look in, recursively
SEARCH_PATHS = [
  "app/assets/javascripts",
  "app/assets/stylesheets",
  "app/helpers",
  "app/presenters",
  "app/views"
]

# Which files do we actually want to search through?
def relevant_dir(s)
  SEARCH_PATHS.find { |d| s.match d }
end

# Which files should we ignore?
def should_ignore(s)
  s.match(/\.DS_Store/) || !s.match(/\./) || s.match(/\/i\//)
end


#----------------------------------
#----------------------------------

# Logger
logger = $stdout#File.new(Rails.root.join("log/#{SCRIPT}.log"), "w+")

# Keep track of which files have references and not
with_references    = []
without_references = []

# Loop through the files
Dir.glob("#{files_base}/**/*.*").each do |file_to_find|
  file_short_name = file_to_find.gsub(files_base, '')

  # Counter of how many times this file is being referenced
  references = 0

  # Loop through each of the files in this project and look for this file.
  # Add the number of matches to references
  Find.find(Rails.root.to_s).select { |s| relevant_dir(s) }.reject { |s| should_ignore(s) }.each do |app_file|
    file    = File.read(app_file)
    matches = file.scan Pathname.new(file_to_find).basename.to_s

    references += matches.size
  end

  # Output the results - how many times did this file turn up in the project?
  if references == 0
    without_references.push file_short_name
    logger.puts "**#{file_short_name}: NO REFERENCES**"
  else
    with_references.push file_short_name
    logger.puts "#{file_short_name}: #{references} reference#{'s' unless references == 1}"
  end

  logger.flush
end

logger.puts ""
logger.puts '####Totals:'
logger.puts "**With References: #{with_references.size}**"
logger.puts "**Without References: #{without_references.size}**"
logger.flush

logger.puts ""
logger.puts '####List'
logger.puts "**With References:**"
logger.puts with_references.inspect
logger.puts ""
logger.puts "**Without References:**"
logger.puts without_references.inspect
logger.flush
