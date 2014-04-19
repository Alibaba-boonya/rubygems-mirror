require 'rubygems'
require 'fileutils'

class Gem::Mirror
  autoload :Fetcher, 'rubygems/mirror/fetcher'
  autoload :Pool, 'rubygems/mirror/pool'

  VERSION = '1.0.1'

  MV = MARSHAL_VERSION = Gem.marshal_version
  SPECS_FILES = [ "specs.#{MV}", "prerelease_specs.#{MV}" ]
  SPECS_FILE_Z = "specs.#{MV}.gz"
  ALL_SPECS_FILES = ["yaml","yaml.Z","latest_specs.#{MV}","latest_specs.#{MV}.gz",
                "Marshal.#{MV}", "Marshal.#{MV}.Z",
                "prerelease_specs.#{MV}","prerelease_specs.#{MV}.gz",
                "specs.#{MV}","specs.#{MV}.gz"]

  DEFAULT_URI = 'http://production.cf.rubygems.org/'
  DEFAULT_TO = File.join(Gem.user_home, '.gem', 'mirror')

  RUBY = 'ruby'

  def initialize(from, to, parallelism = nil)
    require 'rubygems/mirror/backend'
    @from_backend = Gem::Mirror::Backend.new(from)
    @to_backend   = Gem::Mirror::Backend.new(to)


    @from, @to = from, to
    @fetcher = Fetcher.new(@from_backend, @to_backend)
    @pool = Pool.new(parallelism || 10)
  end

  def from *args
    @from_backend.from args
  end

  def update_specs
    SPECS_FILES.each do |sf|
      sfz = "#{sf}.gz"
      @fetcher.fetch(sfz)
      @to_backend.fetch(sfz) do |io, modified_time|
        StringIO.open(Gem.gunzip(io.read)) do |ioo|
          @to_backend.write(ioo, sf)
        end
      end
    end
  end

  def fetch_all_specs
    ALL_SPECS_FILES.each do |spec_file|
      print "Fetching #{spec_file}..."
      @fetcher.fetch(spec_file)
      puts "[Done]"
    end
  end

  def gems
    @gems ||= get_gems
  end

  def existing_gems
    @existing_gems ||= @to_backend.existing_gems
  end

  def existing_gemspecs
    @existing_gemspecs ||= @to_backend.existing_gemspecs
  end

  def gems_to_fetch
    gems - existing_gems
  end

  def gemspecs_to_fetch
    gems.map { |g| "#{g}spec.rz" } - existing_gemspecs
  end

  def gems_to_delete
    existing_gems - gems
  end

  def update_gems
    fetch_all_specs
    puts ""
    puts "-"*100
    print "#{gems_to_fetch.count} Gems need to update"
    gems_to_fetch.each do |g|
      @pool.job do
        @fetcher.fetch(File.join('gems', g))
        print "."
        yield if block_given?
      end
    end
    gemspecs_to_fetch.each do |g_spec|
      @pool.job do
        @fetcher.fetch(File.join("quick/Marshal.#{Gem.marshal_version}", g_spec))
        print "."
        yield if block_given?
      end
    end
    @pool.run_til_done
  end

  def delete_gems
    # gems_to_delete.each do |g|
    #   @pool.job do
    #     File.delete(to('gems', g))
    #     yield if block_given?
    #   end
    # end
    #
    # @pool.run_til_done
  end

  def update
    update_specs
    update_gems
    cleanup_gems
  end


  private

  def get_gems
    gems = []
    SPECS_FILES.each do |sf|
      update_specs unless @to_backend.exists?(sf)

      @to_backend.fetch(sf) do |io, modified_time|
        gems += Marshal.load(io.read)
      end
    end

    gems.map! do |name, ver, plat|
      # If the platform is ruby, it is not in the gem name
      "#{name}-#{ver}#{"-#{plat}" unless plat == RUBY}.gem"
    end
    gems
  end
end
