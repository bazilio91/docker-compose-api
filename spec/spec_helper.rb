$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'byebug'
require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
end

require 'docker-compose'
