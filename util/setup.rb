require File.join(ENV['PROJECT_HOME'], APP, 'config', 'environment')
require File.expand_path('../gist_upload', __FILE__)

URLS = {
  "scprv4" => "scpr.org"
}

Rails.application.default_url_options[:host] = URLS[APP]
