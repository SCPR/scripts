#!/usr/bin/ruby

require 'json'
require 'csv'

days = {}
months = {}
mmonths = {}

ARGV.each do |fname|
  json = ''
  
  File.open(fname) do |f|
    json << f.read()
  end
  
  json =~ /^(.*\})\s*(\{.*)$/m
  
  mdata = JSON.parse($~[1])
  ddata = JSON.parse($~[2])
  
  mdata.each do |show,sv|
    if !months[ show ]
      months[ show ] = {}
    end
    
    sv.each do |month,mv|
      mmonths[month] = 1
      
      if !months[ show ][ month ]
        months[show][month] = { "podcast" => 0, "ondemand" => 0 }
      end

      months[show][month]["podcast"] += mv["podcast"].to_i
      months[show][month]["ondemand"] += mv["ondemand"].to_i
    end
  end
end

# -- output -- #

smonths = mmonths.map {|k,v| k }.sort()

CSV($stdout,:headers => ["Show","Type",smonths].flatten(),:write_headers => true) do |csv|
  months.each do |s,v|
    csv << [s,"podcasts",smonths.map { |m| v[m] ? v[m]["podcast"] : "" }].flatten()
    csv << [s,"ondemand",smonths.map { |m| v[m] ? v[m]["ondemand"] : "" }].flatten()
  end
end