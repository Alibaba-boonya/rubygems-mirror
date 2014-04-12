require 'net/http/persistent'
require 'time'
require 'pry'

class Gem::Aliyun::Fetcher
  # TODO  beef
  class Error < StandardError; end

  attr_reader :bucket

  def initialize bucket
    @http = Net::HTTP::Persistent.new(self.class.name, :ENV)
    @bucket = bucket
  end

  # Fetch a source path under the base uri, and put it in the same or given
  # destination path under the base path.
  def fetch(uri, path)
    modified_time = oss_get(path) && oss_get(path).last_modified.rfc822
    modified_time = "Mon, 07 Apr 2014 07:01:31 GMT"

    req = Net::HTTP::Get.new URI.parse(uri).path
    req.add_field 'If-Modified-Since', modified_time if modified_time

    @http.request URI(uri), req do |resp|
      binding.pry
      return handle_response(resp, path)
    end
  end

  # Handle an http response, follow redirects, etc. returns true if a file was
  # downloaded, false if a 304. Raise Error on unknown responses.
  def handle_response(resp, path)
    case resp.code.to_i
    when 304
    when 302
      fetch resp['location'], path
    when 200
      write_file(resp, path)
    when 403, 404
      warn "#{resp.code} on #{File.basename(path)}"
    else
      raise Error, "unexpected response #{resp.inspect}"
    end
    # TODO rescue http errors and reraise cleanly
  end

  # Efficiently writes an http response object to a particular path. If there
  # is an error, it will remove the target file.
  def write_file(resp, key)
    Aliyun::OSS::OSSObject.store(key, resp.read_body, bucket)
  end

  def oss_get(key)
    Aliyun::OSS::OSSObject.find(key, bucket)
  end
end
