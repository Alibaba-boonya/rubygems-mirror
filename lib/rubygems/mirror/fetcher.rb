require 'time'

class Gem::Mirror::Fetcher
  # TODO  beef
  class Error < StandardError; end

  def initialize from, to
    @from, @to = from, to
    raise ReadOnlyBackend.new("Cannot write to readonly backend #{to}") if to.readonly?

  end

  def fetch(path, &block)
    @from.fetch(path, @to.get_etag(path)) do |io, etag|
      @to.write(io, path)
    end
  end
end
