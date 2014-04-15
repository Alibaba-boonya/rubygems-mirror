require 'time'

class Gem::Mirror::Fetcher
  # TODO  beef
  class Error < StandardError; end

  def initialize from, to
    @from, @to = from, to
    raise ReadOnlyBackend.new("Cannot write to readonly backend #{to}") if to.readonly?

  end

  def fetch(path)
    io, etag = @from.fetch(path, @to.etag(path))
    @to.write(io, path, etag) if io
  end
end
