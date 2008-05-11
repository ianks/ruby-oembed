module OEmbed
  class Provider
    attr_accessor :format, :name, :url, :urls, :endpoint
    
    def initialize(endpoint, format = :json)
      @endpoint = endpoint
      @urls = []
      @format = :json
    end
    
    def <<(url)
      full, scheme, domain, path = *url.match(%r{([^:]*)://?([^/?]*)(.*)})
      domain = Regexp.escape(domain).gsub("\\*", "(.*?)").gsub("(.*?)\\.", "([^\\.]+\\.)?")
      path = Regexp.escape(path).gsub("\\*", "(.*?)")
      @urls << Regexp.new("^#{scheme}://#{domain}#{path}")
    end
    
    def build(url, options = {})
      raise NotFound, "No embeddable content at '#{url}'" unless include?(url)
      query = options.merge({:url => url})
      endpoint = @endpoint.clone
      
      if format_in_url?
        format = endpoint["{format}"] = (query[:format] || @format).to_s
        query.delete(:format)
      else
        format = query[:format] ||= @format
      end
      
      query_string = "?" + query.inject("") do |memo, (key, value)|
        "#{key}=#{value}&#{memo}"
      end.chop
      
      URI.parse(endpoint + query_string)      
    end
    
    def raw(url, options = {})
      uri = build(url, options)
      
      res = Net::HTTP.start(uri.host, uri.port) do |http|
        http.get(uri.path + "?" + uri.query)
      end
      
      case res
      when Net::HTTPNotImplemented
        raise UnknownFormat, "The provider doesn't support the '#{format}' format"
      when Net::HTTPNotFound
        raise NotFound, "No embeddable content at '#{url}'"
      else
        res.body
      end
    end
    
    def get(url, options = {})
      OEmbed::Response.new(raw(url, options.merge(:format => :json)), self)
    end                   
    
    def format_in_url?
      @endpoint.include?("{format}")
    end   
    
    def include?(url)
      !!@urls.detect{ |u| u =~ url } 
    end
  end
end