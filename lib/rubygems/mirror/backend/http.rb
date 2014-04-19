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
        def fetch path, modified_time=nil, &block
          raise ArgumentError.new "no block given" unless block_given?
          _fetch from(path), path, modified_time, &block
        end

        def from *args
          File.join(url, *args)
        end

        private

        def _fetch uri, path, modified_time, &block

          req = Net::HTTP::Get.new URI(uri).path
          req.add_field 'If-None-Since', modified_time if modified_time

          @http.request URI(uri), req do |resp|
            return handle_response(resp, uri, modified_time, &block)
          end

        end

        # Handle an http response, follow redirects, etc. returns true if a file was
        # downloaded, false if a 304. Raise Error on unknown responses.
        def handle_response(resp, path, modified_time, &block)
          case resp.code.to_i
          when 304
            return [nil, get_modified_time(resp)]
          when 302
            _fetch resp['location'], path, modified_time, &block
          when 200
            yield [StringIO.new(resp.read_body), get_modified_time(resp)]
          when 403, 404
            warn "#{resp.code} on #{File.basename(path)}"
            [nil, nil]
          else
            raise "unexpected response #{resp.inspect}"
          end
          # TODO rescue http errors and reraise cleanly
        end

        def get_modified_time resp
          resp["Last-Modified"].gsub(/"/, '') if resp["Last-Modified"]
        end

        def readonly?
          true
        end
      end
    end
  end
end
