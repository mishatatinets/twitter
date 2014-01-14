require 'base64'
require 'faraday'
require 'faraday/request/multipart'
require 'json'
require 'twitter/client'
require 'twitter/error'
require 'twitter/error/configuration_error'
require 'twitter/rest/api/direct_messages'
require 'twitter/rest/api/favorites'
require 'twitter/rest/api/friends_and_followers'
require 'twitter/rest/api/help'
require 'twitter/rest/api/lists'
require 'twitter/rest/api/oauth'
require 'twitter/rest/api/places_and_geo'
require 'twitter/rest/api/saved_searches'
require 'twitter/rest/api/search'
require 'twitter/rest/api/spam_reporting'
require 'twitter/rest/api/suggested_users'
require 'twitter/rest/api/timelines'
require 'twitter/rest/api/trends'
require 'twitter/rest/api/tweets'
require 'twitter/rest/api/undocumented'
require 'twitter/rest/api/users'
require 'twitter/rest/request/multipart_with_file'
require 'twitter/rest/response/parse_json'
require 'twitter/rest/response/raise_error'

module Twitter
  module REST
    # Wrapper for the Twitter REST API
    #
    # @note All methods have been separated into modules and follow the same grouping used in {http://dev.twitter.com/doc the Twitter API Documentation}.
    # @see http://dev.twitter.com/pages/every_developer
    class Client < Twitter::Client
      include Twitter::REST::API::DirectMessages
      include Twitter::REST::API::Favorites
      include Twitter::REST::API::FriendsAndFollowers
      include Twitter::REST::API::Help
      include Twitter::REST::API::Lists
      include Twitter::REST::API::OAuth
      include Twitter::REST::API::PlacesAndGeo
      include Twitter::REST::API::SavedSearches
      include Twitter::REST::API::Search
      include Twitter::REST::API::SpamReporting
      include Twitter::REST::API::SuggestedUsers
      include Twitter::REST::API::Timelines
      include Twitter::REST::API::Trends
      include Twitter::REST::API::Tweets
      include Twitter::REST::API::Undocumented
      include Twitter::REST::API::Users
      attr_accessor :bearer_token
      attr_writer :connection_options, :middleware
      ENDPOINT = 'https://api.twitter.com'

      def connection_options
        @connection_options ||= {
          :builder => middleware,
          :headers => {
            :accept => 'application/json',
            :user_agent => user_agent,
          },
          :request => {
            :open_timeout => 5,
            :timeout => 10,
          },
        }
      end

      # @note Faraday's middleware stack implementation is comparable to that of Rack middleware.  The order of middleware is important: the first middleware on the list wraps all others, while the last middleware is the innermost one.
      # @see https://github.com/technoweenie/faraday#advanced-middleware-usage
      # @see http://mislav.uniqpath.com/2011/07/faraday-advanced-http/
      # @return [Faraday::RackBuilder]
      def middleware
        @middleware ||= Faraday::RackBuilder.new do |faraday|
          # Convert file uploads to Faraday::UploadIO objects
          faraday.request :multipart_with_file
          # Checks for files in the payload, otherwise leaves everything untouched
          faraday.request :multipart
          # Encodes as "application/x-www-form-urlencoded" if not already encoded
          faraday.request :url_encoded
          # Handle error responses
          faraday.response :raise_error
          # Parse JSON response bodies
          faraday.response :parse_json
          # Set default HTTP adapter
          faraday.adapter :net_http
        end
      end

      # Perform an HTTP GET request
      def get(path, params = {})
        request(:get, path, params)
      end

      # Perform an HTTP POST request
      def post(path, params = {})
        signature_params = params.values.any? { |value| value.respond_to?(:to_io) } ? {} : params
        request(:post, path, params, signature_params)
      end

      # @return [Boolean]
      def bearer_token?
        !!bearer_token
      end

      # @return [Boolean]
      def credentials?
        super || bearer_token?
      end

    private

      # Returns a Faraday::Connection object
      #
      # @return [Faraday::Connection]
      def connection
        @connection ||= Faraday.new(ENDPOINT, connection_options)
      end

      def request(method, path, params = {}, signature_params = params)
        response = connection.send(method.to_sym, path, params) do |request|
          request.headers.update(request_headers(method, path, params, signature_params))
        end
        response.env
      rescue Faraday::Error::ClientError, JSON::ParserError => error
        raise Twitter::Error.new(error) # rubocop:disable RaiseArgs
      end

      def request_headers(method, path, params = {}, signature_params = params)
        bearer_token_request = params.delete(:bearer_token_request)
        headers = {}
        if bearer_token_request
          headers[:accept]        = '*/*'
          headers[:authorization] = bearer_token_credentials_auth_header
          headers[:content_type]  = 'application/x-www-form-urlencoded; charset=UTF-8'
        else
          headers[:authorization] = auth_token(method, path, params, signature_params)
        end
        headers
      end

      def auth_token(method, path, params = {}, signature_params = params)
        if !user_token?
          @bearer_token = token unless bearer_token?
          bearer_auth_header
        else
          oauth_auth_header(method, ENDPOINT + path, signature_params).to_s
        end
      end

      # Generates authentication header for a bearer token request
      #
      # @return [String]
      def bearer_token_credentials_auth_header
        basic_auth_token = strict_encode64("#{@consumer_key}:#{@consumer_secret}")
        "Basic #{basic_auth_token}"
      end

      def bearer_auth_header
        token = bearer_token.is_a?(Twitter::Token) && bearer_token.bearer? ? bearer_token.access_token : bearer_token
        "Bearer #{token}"
      end

      # Base64.strict_encode64 is not available on Ruby 1.8.7
      def strict_encode64(str)
        Base64.encode64(str).gsub("\n", '')
      end
    end
  end
end
