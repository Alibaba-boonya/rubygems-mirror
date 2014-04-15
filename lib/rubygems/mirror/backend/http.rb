require "net/http/persistent"

module Gem
  class Mirror
    module Backend
      class HTTP < ::Gem::Mirror::Backend::Base
        attr_reader :url

        DEFAULT_URI = 'http://production.cf.rubygems.org/'

        def initialize attributes
          attributes = attributes.dup
          @url = attributes.delete("url") || DEFAULT_URL
          @http = Net::HTTP::Persistent.new(self.class.name, :ENV)
        end

        # Fetch a source path under the base uri, and put it in the same or given
        # destination path under the base path.
        def fetch path, etag=nil

          req = Net::HTTP::Get.new "/#{path}"
          req.add_field 'If-None-Match', etag if etag

          @http.request URI(from(path)), req do |resp|
            return handle_response(resp, path, etag)
          end
        end

        def from *args
          File.join(url, *args)
        end

        private

        # Handle an http response, follow redirects, etc. returns true if a file was
        # downloaded, false if a 304. Raise Error on unknown responses.
        def handle_response(resp, path, etag)
          case resp.code.to_i
          when 304
            return [nil, get_etag(resp)]
          when 302
            fetch resp['location'], path, etag
          when 200
            [StringIO.new(resp.body), get_etag(resp)]
          when 403, 404
            warn "#{resp.code} on #{File.basename(path)}"
            [nil, nil]
          else
            raise Error, "unexpected response #{resp.inspect}"
          end
          # TODO rescue http errors and reraise cleanly
        end

        def get_etag resp
          resp["ETAG"].gsub(/"/, '') if resp["ETAG"]
        end

        def readonly?
          true
        end
      end
    end
  end
end
