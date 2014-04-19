require 'time'

class Gem::Mirror::Fetcher
  # TODO  beef
  class Error < StandardError; end

  def initialize from, to
    @from, @to = from, to
    raise ReadOnlyBackend.new("Cannot write to readonly backend #{to}") if to.readonly?

  end

  def fetch(path, &block)
    @from.fetch(path, @to.get_modified_time(path)) do |io, modified_time|
      @to.write(io, path)
    end
  end
end
