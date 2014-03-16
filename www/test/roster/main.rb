#!/usr/bin/ruby

# while under development, use tip versions of wunderbar and ruby2js
$:.unshift '/home/rubys/git/wunderbar/lib'
$:.unshift '/home/rubys/git/ruby2js/lib'

#
# Server side router/controllers
#

require '/var/tools/asf'

require 'wunderbar/sinatra'
require 'wunderbar/bootstrap/theme'
require 'wunderbar/angularjs/route'
require 'wunderbar/jquery/filter'
require 'wunderbar/underscore'
require 'ruby2js/filter/functions'

require_relative 'model/ldap'

set :views, File.dirname(__FILE__)

get '/' do
  @base = env['REQUEST_URI']
  _html :'views/main'
end

get %r{/(committer/.*)} do |path|
  @base = URI.parse(env['REQUEST_URI']).path.chomp(path)
  _html :'views/main'
end

get %r{/(committee/.*)} do |path|
  @base = env['REQUEST_URI'].chomp(path)
  _html :'views/main'
end

get %r{/(group/.*)} do |path|
  @base = env['REQUEST_URI'].chomp(path)
  _html :'views/main'
end

get '/js/:file.js' do
  _js :"js/#{params[:file]}"
end

get '/partials/:file.html' do
  _html :"partials/#{params[:file]}"
end

configure do
  @@ldap_cache = nil
  @@ldap_etag = nil
end

get '/json/auth' do
  _json do
    auth = {}
    ASF::Authorization.new.each { |group, list| auth[group] = list }
    _! auth
  end
end

get '/json/info' do
  _json do
    committees = ASF::Committee.load_committee_info
    _! Hash[committees.map { |committee| 
      [committee.name.gsub(/[^-\w]/,''), {
        display_name: committee.display_name,
        report: committee.report,
        chair: committee.chair.id,
        memberUid: committee.info,
        emeritus: committee.emeritus
      }]
    }]
  end
end

get '/json/ldap' do
  cache_control :private, :no_cache, :must_revalidate, max_age: 0

  cache_control = env['HTTP_CACHE_CONTROL'].to_s.downcase.split(/,\s+/)
  if cache_control.include? 'only-if-cached'
    etag @@ldap_etag if @@ldap_etag
    throw :halt, 504 unless @ldap_cache
  else
    @@ldap_cache = JSON.dump(ASF::RosterLDAP.get)
    @@ldap_etag = Digest::MD5.hexdigest(@@ldap_cache)
    etag @@ldap_etag
  end

  @@ldap_cache
end

get '/json/mail' do
  _json do
    _! ASF::Mail.lists(true)
  end
end

post '/json/:file' do
  _json :"json/#{params[:file]}"
end
