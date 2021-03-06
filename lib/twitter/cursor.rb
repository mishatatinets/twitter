require 'twitter/enumerable'
require 'twitter/utils'

module Twitter
  class Cursor
    include Twitter::Enumerable
    include Twitter::Utils
    attr_reader :attrs
    alias_method :to_h, :attrs
    deprecate_alias :to_hash, :to_h
    deprecate_alias :to_hsh, :to_h

    class << self
      # Construct a new Cursor object from a response hash
      #
      # @param response [Hash]
      # @param key [String, Symbol] The key to fetch the data from the response
      # @param klass [Class] The class to instantiate objects in the response
      # @param request [Twitter::Request]
      # @return [Twitter::Cursor]
      def from_response(response, key, klass, request)
        new(response[:body], key, klass, request)
      end
    end

    # Initializes a new Cursor
    #
    # @param attrs [Hash]
    # @param key [String, Symbol] The key to fetch the data from the response
    # @param klass [Class] The class to instantiate objects in the response
    # @param request [Twitter::Request]
    # @return [Twitter::Cursor]
    def initialize(attrs, key, klass, request)
      @key = key.to_sym
      @klass = klass
      @client = request.client
      @request_method = request.verb
      @path = request.path
      @options = request.options
      @collection = []
      self.attrs = attrs
    end

  private

    def next_cursor
      @attrs[:next_cursor] || -1
    end
    alias_method :next, :next_cursor

    # @return [Boolean]
    def last?
      next_cursor.zero?
    end

    def fetch_next_page
      response = @client.send(@request_method, @path, @options.merge(:cursor => next_cursor))
      self.attrs = response[:body]
    end

    def attrs=(attrs)
      @attrs = attrs
      Array(attrs[@key]).each do |element|
        @collection << (@klass ? @klass.new(element) : element)
      end
    end
  end
end
