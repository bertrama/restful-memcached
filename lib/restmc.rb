require 'rubygems'
require 'sinatra/base'
require 'yaml'
require 'torquebox/cache'

##
# The general pattern is:
# base_url/ for all caches
# base_url/:cache for one cache
# base_url/:cache/:key for one value
# GET to read data, PUT to write data
# POST will only set a key if empty
#
# For all actions, if the cache doesn't exist create it.

module RESTmc
  class Application < Sinatra::Base
    mime_type :text, 'text/plain'
    set :reload_templates, false  # we have no templates

    ENABLE_MARSHAL = FALSE
    DEFAULT_TTL = 0  # never expire; use @mc.options[:default_ttl] for the client default of 1 week

    def initialize
      @caches = {}
      @defaults = { :name => nil }
    end

    # Our return values should all be content-type: text/plain
    before do
      content_type :text
    end

    # GET / should list the cache bins.
    get '/' do
      @caches.keys.join("\n")
    end

    # GET /:cache/ should list the keys for the bin.
    get '/:cache/' do
      cache = params[:cache]
      @caches[cache] ||= TorqueBox::Infinispan::Cache.new(@defaults.merge({:name => cache}))
      @caches[cache].keys.join("\n");
    end

    # GET /:cache/* should fetch the value for the key *.
    get '/:cache/*' do
      cache = params[:cache]
      key   = splat_to_key(params[:splat])
      @caches[cache] ||= TorqueBox::Infinispan::Cache.new(@defaults.merge({:name => cache}))
      begin
        @caches[cache].get(key).to_s
      rescue Exception => e
        status 404
        '404 File not found'
      end
    end

    # PUT /:cache/+/* should increment the value for the key *.
    put '/:cache/+/*' do
      begin
        cache = params[:cache]
        key   =  splat_to_key(params[:splat])
        @caches[cache] ||= TorqueBox::Infinispan::Cache.new(@defaults.merge({:name => cache}))
        data  = request.body.read.to_i
        data  = 1 if data < 1
        @caches[cache].increment(key, data).to_s
      rescue TypeError
        @caches[cache].put(key, @caches[cache].get(key).to_i + data).to_s
      rescue Exception => e
        @caches[cache].put(key, data, get_ttl).to_s
      end
    end

    # PUT /:cache/-/* should increment the value for the key *.
    put '/:cache/-/*' do
      begin
        cache = params[:cache]
        key   = splat_to_key(params[:splat])
        @caches[cache] ||= TorqueBox::Infinispan::Cache.new(@defaults.merge({:name => cache}))
        data  = request.body.read.to_i
        data  = 1 if data < 1
        @caches[cache].decrement(key, data).to_s
      rescue TypeError
        @caches[cache].put(key, @caches[cache].get(key).to_i + data).to_s
      rescue Exception => e
        @caches[cache].put(key, 1 - data, get_ttl).to_s
      end
    end

    # PUT /:cache/* should put the value for the key *.
    put '/:cache/*' do
      cache = params[:cache]
      key   = splat_to_key(params[:splat])
      @caches[cache] ||= TorqueBox::Infinispan::Cache.new(@defaults.merge({:name => cache}))
      @caches[cache].put(key, request.body.read, get_ttl).to_s
    end

    # POST /:cache/* should put_if_absent the value for the key *.
    post '/:cache/*' do
      begin
        cache = params[:cache]
        key   = splat_to_key(params[:splat])
        @caches[cache] ||= TorqueBox::Infinispan::Cache.new(@defaults.merge({:name => cache}))
        data = request.body.read
        data = data.to_i if data.match(/^\d+$/)
        @caches[cache].put_if_absent(key, data, get_ttl).to_s
      rescue Exception => e
        status 409
        '409 status'
      end
    end

    # DELETE /:cache/ should clear the cache.
    delete '/:cache/' do
      begin
        cache = params[:cache]
        @caches[cache] ||= TorqueBox::Infinispan::Cache.new(@defaults.merge({:name => cache}))
        @caches[cache].clear
        'Cache Cleared'
      rescue Exception => e
        status 400
      end
    end

    # DELETE /:cache/ should remove the key *. 
    delete '/:cache/*' do
      begin
        cache = params[:cache]
        key   = splat_to_key(params[:splat])
        @caches[cache] ||= TorqueBox::Infinispan::Cache.new(@defaults.merge({:name => cache}))
        @caches[cache].remove(key).to_s
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
