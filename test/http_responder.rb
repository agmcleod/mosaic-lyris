require 'net/http'
require 'cgi'

module Net
  class HTTPOK
    def set_body(body)
      @read = true
      @body = body
      self
    end

    def self.with_body(body)
      new('1.1','200','OK').set_body(body)
    end
  end

  class HTTP
    def request_with_capture(req, body = nil, &block)
      response = request_without_capture(req, body, &block)
      File.open(@capture_response, "w") do |file|
        file.write response.body
      end if @capture_response
      response
    end
    alias_method :request_without_capture, :request
    alias_method :request, :request_with_capture

    def request_with_http_fixtures(req, body = nil, &block)
      if response_body = self.class.response_for(req.method, req.path, req.body)
        HTTPOK.with_body(response_body)
      else
        raise "HTTP requests are blocked!" if self.class.block_requests?
        request_without_http_fixtures(req, body, &block)
      end
    end
    alias_method :request_without_http_fixtures, :request
    alias_method :request, :request_with_http_fixtures

    class << self
      def block_requests(value = true)
        @block_requests = value
      end

      def block_requests?
        @block_requests
      end

      def capture_response(to = true)
        @capture_response = (to == true) ? "capture.log" : to
      end

      def get_form_data(body)
        body.split('&').inject({}) do |data,parameter|
          name, value = parameter.split('=')
          data[urldecode(name)] = urldecode(value)
          data
        end
      end

      def respond_to(method, path, response_file, request_conditions = nil)
        responses_by_method_and_path(method, path) << [request_conditions,File.read(response_file)]
      end

      def response_for(method, path, body)
        data = get_form_data(body)
        responses_by_method_and_path(method, path).each do |request_conditions,response_body|
          return response_body if request_conditions.nil? || request_conditions.all? { |(k,v)| v === data[k.to_s] }
        end
        nil
      end

      def responses
        @responses ||= {}
      end

      def responses_by_method(method)
        responses[method.to_s.upcase] ||= {}
      end

      def responses_by_method_and_path(method, path)
        responses_by_method(method)[path.to_s.downcase] ||= []
      end

      def urldecode(str)
        CGI.unescape(str)
      end
    end
  end
end
