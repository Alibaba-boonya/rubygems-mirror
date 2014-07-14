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
        def fetch path, etag=nil, &block
          raise ArgumentError.new "no block given" unless block_given?
          _fetch from(path), path, etag, &block
        end

        def from *args
          File.join(url, *args)
        end

        private

        def _fetch uri, path, etag, &block

          req = Net::HTTP::Get.new URI(uri).path
          req.add_field 'If-None-Match', etag if etag

          @http.request URI(uri), req do |resp|
            return handle_response(resp, uri, etag, &block)
          end

        end

        # Handle an http response, follow redirects, etc. returns true if a file was
        # downloaded, false if a 304. Raise Error on unknown responses.
        def handle_response(resp, path, etag, &block)
          case resp.code.to_i
          when 304
            et = get_etag(resp)
            puts "  304 Not modified with etag #{et}"
            return [nil, get_etag(resp)]
          when 302
            _fetch resp['location'], path, etag, &block
          when 200
            yield [StringIO.new(resp.read_body), get_etag(resp)]
          when 403, 404
            puts "  #{resp.code} on #{File.basename(path)}"
            [nil, nil]
          else
            raise "  unexpected response #{resp.inspect}"
          end
          # TODO rescue http errors and reraise cleanly
        end

        def get_modified_time resp
          resp["Last-Modified"].gsub(/"/, '') if resp["Last-Modified"]
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
