require 'rubygems/aliyun'
require 'rubygems/command'
require 'aliyun/oss'
require 'yaml'

class Gem::Commands::AliyunCommand < Gem::Command
  SUPPORTS_INFO_SIGNAL = Signal.list['INFO']

  def initialize
    super 'aliyun', 'Mirror a gem repository to aliyun'
  end

  def description # :nodoc:
    <<-EOF
The mirror command uses the ~/.gem/.mirrorrc config file to mirror
remote gem repositories to a local path. The config file is a YAML
document that looks like this:

  ---
  - from: http://gems.example.com         # source repository URI
    bucket: bucket_name                   # destination Aliyun OSS Bucket
    parallelism: 10                       # use 10 threads for downloads
    aliyun_access_key_id: <id>            # aliyun API access key
    aliyun_secret_access_key: <secret>    # aliyun API secret access key

Multiple sources and destinations may be specified.
    EOF
  end

  def execute
    config_file = File.join Gem.user_home, '.gem', '.mirrorrc'

    raise "Config file #{config_file} not found" unless File.exist? config_file

    mirrors = YAML.load_file config_file

    raise "Invalid config file #{config_file}" unless mirrors.respond_to? :each

    mirrors.each do |mir|
      %w/from bucket aliyun_access_key_id aliyun_secret_access_key/.each do |key|
        raise %/mirror missing '#{key}' fields/ unless mir.has_key? key
      end

      get_from          = mir['from']
      save_to           = mir['bucket']
      parallelism       = mir['parallelism']
      access_key_id     = mir['aliyun_access_key_id']
      secret_access_key = mir['aliyun_secret_access_key']

      ::Aliyun::OSS::Base.establish_connection!(
        :access_key_id     => access_key_id,
        :secret_access_key => secret_access_key
      )

      begin
        ::Aliyun::OSS::Bucket.find(save_to)
      rescue ::Aliyun::OSS::AccessDenied
        raise %/Do you have access to Bucket "#{save_to}"?/
      end

      mirror = Gem::Aliyun.new(get_from, save_to, parallelism)
      say "Fetching: #{mirror.from(Gem::Aliyun::SPECS_FILE_Z)} with #{parallelism} threads"
      mirror.update_specs

      say "Total gems: #{mirror.gems.size}"

      num_to_fetch = mirror.gems_to_fetch.size

      progress = ui.progress_reporter num_to_fetch,
                                  "Fetching #{num_to_fetch} gems"

      trap(:INFO) { puts "Fetched: #{progress.count}/#{num_to_fetch}" } if SUPPORTS_INFO_SIGNAL

      mirror.update_gems { progress.updated true }

      num_to_delete = mirror.gems_to_delete.size

      progress = ui.progress_reporter num_to_delete,
                                 "Deleting #{num_to_delete} gems"

      trap(:INFO) { puts "Fetched: #{progress.count}/#{num_to_delete}" } if SUPPORTS_INFO_SIGNAL

      mirror.delete_gems { progress.updated true }
    end
  end
end
