require 'aliyun/oss'
require 'redis'
require 'redis-namespace'

module Gem
  class Mirror
    module Backend
      class AliyunOSS < ::Gem::Mirror::Backend::Base

        DEFAULT_SERVER = "oss-internal.aliyuncs.com"


        def initialize attributes
          attributes = attributes.dup

          @access_key_id     = attributes.delete("access_key_id")
          @secret_access_key = attributes.delete("secret_access_key")
          @server            = attributes.delete("server")   || DEFAULT_SERVER
          @bucket_name       = attributes.delete("bucket")
          @max_keys          = attributes.delete("max_keys") || 1000
          @namespace         = attributes.delete("namespace")

          @existing_gems_key     = "gems"
          @existing_gemspecs_key = "quick"

          connection_prepare
        end

        def readonly?
          false
        end

        def fetch path, etag=nil, &block
          raise ArgumentError.new "no block given" unless block_given?
          warn "feching #{path} from oss bucket #{@bucket_name}"
          oss_obj = oss_find(path)
          yield [StringIO.new(oss_obj.value), get_etag(oss_obj)]
        end

        def existing_gems
          redis.smembers(@existing_gems_key)
        end

        def existing_gemspecs
          redis.smembers(@existing_gemspecs_key)
        end

        def update_existing_gems
          travel_all_files(prefix: "gems") do |oss_obj|
            redis_add oss_obj.key
          end
        end

        def update_existing_gemspecs
          travel_all_files(prefix: "quick") do |oss_obj|
            redis_add oss_obj.key
          end
        end

        def exists? path
          ::Aliyun::OSS::OSSObject.exists? gen_path(path), @bucket_name
        end

        def write(from, path)
          warn "store #{path} to oss bucket #{@bucket_name}"
          redis_add path
          ::Aliyun::OSS::OSSObject.store gen_path(path), from.read, @bucket_name
        end

        def get_etag arg
          case arg
          when String
            exists?(arg) ?  oss_find(arg).etag.downcase : nil

          when ::Aliyun::OSS::OSSObject
            arg.etag.downcase

          end
        end

        private

        # OSS 的 Bucket Object List 速度太慢, 所以引入 Redis 做一级缓存
        def redis
          @redis ||= ::Redis::Namespace.new("rubygems-china", redis: ::Redis.new)
        end

        def redis_add args
          args = args.dup.split('/')
          case args.length
          when 1
            key = 'root'
            value = args[0]
          else
            key = File.join(args[0..-2])
            value = args[-1]
          end
          redis.sadd(key, value)
        end

        def bucket
          @bucket ||= ::Aliyun::OSS::Bucket.find(@bucket_name)
        end

        def oss_find path
          ::Aliyun::OSS::OSSObject.find(gen_path(path), @bucket_name)
        end

        def travel_all_files options={}
          options = options.dup
          prefix = gen_path(options.delete(:prefix))
          marker = options[:marker]
          files = []

          loop do
            warn %/travel_all_files in oss bucket "#{@bucket_name}" with prefix "#{prefix}" marker "#{marker}"/
            _tmps = bucket.objects(max_keys: @max_keys, marker: marker, prefix: prefix)

            break if _tmps.empty?

            files += _tmps.map {|obj| yield obj}

            marker = _tmps.last.key
          end

          files
        end

        def connection_prepare
          opts = {
            :access_key_id     => @access_key_id,
            :secret_access_key => @secret_access_key,
          }
          opts.merge(server: @server)

          ::Aliyun::OSS::Base.establish_connection!(opts)
        end

        def gen_path *args
          File.join([@namespace, *args].compact)
        end
      end
    end
  end
end
