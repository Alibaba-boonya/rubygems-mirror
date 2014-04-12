require 'rubygems'
require 'fileutils'
require 'aliyun/oss'

class Gem::Aliyun
  autoload :Fetcher, 'rubygems/aliyun/fetcher'
  autoload :Pool, 'rubygems/aliyun/pool'


  VERSION = '1.0.1'

  SPECS_FILE = "specs.#{Gem.marshal_version}"
  SPECS_FILE_Z = "specs.#{Gem.marshal_version}.gz"

  RUBY = 'ruby'

  def initialize(from, bucket_name, parallelism = nil)
    @from = from
    @bucket_name = bucket_name
    @fetcher = Fetcher.new(bucket_name)
    @pool = Pool.new(parallelism || 10)
  end

  def from(*args)
    File.join(@from, *args)
  end

  # key for store in bucket
  def to(*args)
    File.join(*args)
  end

  def update_specs
    specz = to(SPECS_FILE_Z)
    @fetcher.fetch(from(SPECS_FILE_Z), specz)
    oss_write(SPECS_FILE, Gem.gunzip(oss_get_value(specz)))
    reload_bucket
  end


  def gems
    update_specs unless File.exists?(to(SPECS_FILE))

    @gems ||= Marshal.load(oss_get_value(to(SPECS_FILE))).map { |name, ver, plat|
      # If the platform is ruby, it is not in the gem name
      "#{name}-#{ver}#{"-#{plat}" unless plat == RUBY}.gem"
    }
  end

  def existing_gems
    bucket.objects.map(&:key).map { |f| File.basename(f) }
  end

  def gems_to_fetch
    gems - existing_gems
  end

  def gems_to_delete
    existing_gems - gems
  end

  def update_gems
    gems_to_fetch.each do |g|
      @pool.job do
        @fetcher.fetch(from('gems', g), to('gems', g))
        yield if block_given?
      end
    end

    @pool.run_til_done
  end

  def delete_gems
    gems_to_delete.each do |g|
      @pool.job do
        File.delete(to('gems', g))
        yield if block_given?
      end
    end

    @pool.run_til_done
  end

  def update
    update_specs
    update_gems
    cleanup_gems
  end

  private

  def bucket
    @bucket ||= Aliyun::OSS::Bucket.find(@bucket_name)
  end

  def reload_bucket
    @bucket = nil
    bucket
  end

  def oss_get key
    puts "get from aliyun oss #{@bucket_name} #{key}"
    Aliyun::OSS::OSSObject.find(key, @bucket_name)
  end

  def oss_get_value key
    oss_get(key).value
  end

  def oss_write key, content
    puts "store to aliyun oss #{@bucket_name} #{key}"
    Aliyun::OSS::OSSObject.store key, content, @bucket_name
  end
end
