require 'rubygems'
require 'sinatra/base'
require 'yaml'
require 'torquebox/cache'

def reload_fn cache, key, value
  # (val.to_i + value).to_s
  val = cache.get(key)
  cache.put(key, val.to_i + value)
  cache.get(key).to_s
end

module RESTmc
  class Application < Sinatra::Base
    mime_type :text, 'text/plain'
    set :reload_templates, false  # we have no templates

    ENABLE_MARSHAL = FALSE
    DEFAULT_TTL = 0  # never expire; use @mc.options[:default_ttl] for the client default of 1 week

    def initialize
      @cache = TorqueBox::Infinispan::Cache.new
    end

    before do
      content_type :text
    end

    put '/' do
      load 'lib/restmc.rb'
      "reload"
    end

    get '/' do
      @cache.keys.join("\n")
    end

    get '/*' do
      begin
        @cache.get(splat_to_key(params[:splat])).to_s
      rescue Exception => e
        status 404
        ''
      end
    end

    put '/+/*' do
      begin
        key =  splat_to_key(params[:splat])
        data = request.body.read.to_i
        data = 1 if data < 1
        @cache.increment(key, data).to_s
      rescue TypeError
        @cache.put(key, @cache.get(key).to_i + data).to_s
      rescue Exception => e
        @cache.put(key, data, get_ttl).to_s
      end
    end

    put '/-/*' do
      begin
        key = splat_to_key(params[:splat])
        data = request.body.read.to_i
        data = 1 if data < 1
        @cache.decrement(key, data).to_s
      rescue TypeError
        @cache.put(key, @cache.get(key).to_i + data).to_s
      rescue Exception => e
        @cache.put(key, 1 - data, get_ttl).to_s
      end
    end

    put '/*' do
      @cache.put(splat_to_key(params[:splat]), request.body.read, get_ttl).to_s
    end

    post '/*' do
      begin
        data = request.body.read
        data = data.to_i if data.match(/^\d+$/)
        @cache.put_if_absent(splat_to_key(params[:splat]), data, get_ttl).to_s
      rescue Exception => e
        status 409
        ''
      end
    end

    delete '/' do
      begin
        @cache.clear
        'Cache Cleared'
      rescue Exception => e
        status 400
      end
    end

    delete '/*' do
      begin
        @cache.remove(splat_to_key(params[:splat])).to_s
      rescue Exception => e
        status 404
      end
    end

    private

    def splat_to_key(splat)
      key = splat.first.split(/\//).join(':')
      halt 404 if key.length == 0 || /\s/ =~ key
      key
    end

    def get_ttl
      ttl = DEFAULT_TTL
      if request.env['HTTP_CACHE_CONTROL']
        control = request.env['HTTP_CACHE_CONTROL'].split(/\=/)
        ttl = control.last.to_i if control.first == 'max-age'
      end
      ttl
    end
  end
end
