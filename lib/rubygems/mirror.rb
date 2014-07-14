require 'rubygems'
require 'fileutils'

class Gem::Mirror
  autoload :Fetcher, 'rubygems/mirror/fetcher'
  autoload :Pool, 'rubygems/mirror/pool'

  VERSION = '1.1.0'

  MV = MARSHAL_VERSION = Gem.marshal_version
  SPECS_FILES = [ "specs.#{MV}", "prerelease_specs.#{MV}" ]
  
  OTHER_SPECS_FILES = %W(yaml.Z yaml Marshal.#{MV}.Z Marshal.#{MV})
  ALL_SPEC_GZ_FILES = %W(latest_specs.#{MV}.gz prerelease_specs.#{MV}.gz specs.#{MV}.gz)
  ALL_SPEC_FILES = %W(yaml.Z latest_specs.#{MV}.gz Marshal.#{MV}.Z prerelease_specs.#{MV}.gz specs.#{MV}.gz 
                      yaml latest_specs.#{MV} Marshal.#{MV} prerelease_specs.#{MV} specs.#{MV})

  DEFAULT_URI = 'http://production.cf.rubygems.org/'
  TEMP_LOCAL_PATH = "/tmp/.rubygems-mirror"
  RUBY = 'ruby'

  def initialize(from, to, parallelism = nil)
    require 'rubygems/mirror/backend'
    
    if !Dir.exist?(TEMP_LOCAL_PATH)
      Dir.mkdir(TEMP_LOCAL_PATH)
    end
    
    @temp_local_backend = Gem::Mirror::Backend.new({ 'provider' => 'local', 'path' => TEMP_LOCAL_PATH })
    @from_backend = Gem::Mirror::Backend.new(from)
    @to_backend   = Gem::Mirror::Backend.new(to)
    
    @from, @to = from, to
    
    @temp_fetcher = Fetcher.new(@from_backend, @temp_local_backend)
    @fetcher = Fetcher.new(@temp_local_backend, @to_backend)
    @gem_fetcher = Fetcher.new(@from_backend, @to_backend)
    @pool = Pool.new(parallelism || 10)
  end

  def from *args
    @from_backend.from args
  end

  def update_specs_in_local
    ALL_SPEC_GZ_FILES.each do |sfz|
      @temp_fetcher.fetch(sfz)

      gzip_path = File.join(TEMP_LOCAL_PATH, sfz)
      sf_path = gzip_path.gsub(/\.(Z|gz)$/,"")
      puts "  unzip #{sfz}"
      open(sf_path, 'wb') do |f| 
        f << Gem.gunzip(Gem.read_binary(gzip_path))
      end
    end
    
    OTHER_SPECS_FILES.each do |sfz| 
      @temp_fetcher.fetch(sfz)
    end
  end
  
  def update_specs
    ALL_SPEC_FILES.each do |sf|
      @fetcher.fetch(sf)
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
    puts ""
    puts "-" * 100
    puts "#{gems_to_fetch.count} Gems need to update"
    puts ""
    
    gems_to_fetch.each do |g|
      @pool.job do
        puts "Update #{g}"
        @gem_fetcher.fetch(File.join('gems', g))
        yield if block_given?
      end
    end
    
    gemspecs_to_fetch.each do |g_spec|
      @pool.job do
        @gem_fetcher.fetch(File.join("quick/Marshal.#{Gem.marshal_version}", g_spec))
        yield if block_given?
      end
    end
    @pool.run_til_done
  end

  def delete_gems
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
      update_specs unless @temp_local_backend.exists?(sf)

      @temp_local_backend.fetch(sf) do |io, etag|
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
