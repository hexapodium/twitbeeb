#!/usr/bin/ruby

# A Twitter OAuth Class
# by Barney Livingston
# 2012-05-31

require 'uri'
require 'hmac-sha1'
require 'base64'
require 'net/https'
require 'time'

class TwitterOauth

	@@DOMAIN="api.twitter.com"
	@@DEBUG=false


	attr_accessor :oauth_token, :oauth_token_secret

	def initialize(consumer_key, consumer_secret, oauth_token="", oauth_token_secret="")
		@consumer_key = consumer_key
		@consumer_secret = consumer_secret
		@oauth_token = oauth_token
		@oauth_token_secret = oauth_token_secret
	end

	def request(path, oauth_token_secret="", params={}, body={}, method="POST")
		params["oauth_consumer_key"] = @consumer_key
		params["oauth_signature_method"] = "HMAC-SHA1"
		params["oauth_version"] = "1.0"
		params["oauth_nonce"] = Base64.encode64("TwitterOAuth " + Time.now.to_f.to_s).chomp
		params["oauth_timestamp"] = Time.now.to_i.to_s
		params["oauth_signature"] = signreq("#{@consumer_secret}&#{oauth_token_secret}", method, "https://#{@@DOMAIN}#{path}", params, body)

		auth_header = "OAuth " + params.keys.sort.map { |key|
			escape(key) + "=\"" + escape(params[key]) + "\""
		}.join(", ")
		puts auth_header if @@DEBUG

		body_str = body.keys.sort.map { |key|
			escape(key) + "=" + escape(body[key])
		}.join("&")
		puts body_str if @@DEBUG

		http = Net::HTTP.new(@@DOMAIN, 443)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE

		if method == "POST" then
			return http.post(path, body_str, { 'Authorization' => auth_header })
		elsif method == "GET" then
			return http.get(path + "?" + body_str, { 'Authorization' => auth_header })
		else
			puts "ERROR: bad HTTP method: #{method}"
			exit 1
		end
	end

	def tweet(text)
		request("/1.1/statuses/update.json", @oauth_token_secret, { 'oauth_token' => @oauth_token }, { "status" => text })
	end

	def tweet_geo(text, lat, long)
		request("/1.1/statuses/update.json", @oauth_token_secret, { 'oauth_token' => @oauth_token }, { "status" => text, "lat" => lat.to_s, "long" => long.to_s, "display_coordinates" => "true" })
	end

	def search(q)
		request("/1.1/search/tweets.json", @oauth_token_secret, { 'oauth_token' => @oauth_token }, { "q" => q }, "GET")
	end

	def get_request_token()
		request("/oauth/request_token", "", { 'oauth_callback' => 'oob' })
	end

	def get_access_token(verifier)
		request("/oauth/access_token", @oauth_token_secret, { 'oauth_token' => @oauth_token, "oauth_verifier" => verifier })
	end


	private

	def signreq(sign_key, http_method, base_uri, params, body={})
		all_params = params.merge(body)
		sign_string = http_method + "&" +
			escape(base_uri) + "&" +
			escape(all_params.keys.sort.map { |key|
				escape(key) + "=" +
				escape(all_params[key])
			}.join("&"))
			puts sign_string if @@DEBUG
		return Base64.encode64(HMAC::SHA1.digest(sign_key, sign_string)).chomp
	end

	def escape(str)
		return URI.escape(str, /[^A-Za-z0-9\-\._~]/)
	end

end
