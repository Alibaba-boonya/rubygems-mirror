require 'digest/md5'

module Gem
  class Mirror
    module Backend
      class Local < ::Gem::Mirror::Backend::Base
        attr_reader :base_path

        DEFAULT_PATH = File.join(Gem.user_home, '.gem', 'mirror')

        def initialize attributes
          attributes = attributes.dup
          @base_path = attributes.delete("path") || DEFAULT_PATH
          raise "Directory not found: #{@base_path}" unless File.exist? base_path
          raise "Not a directory: #{@base_path}" unless File.directory? base_path
        end

        def exists? path
          File.exists? gen_path(path)
        end

        def existing_gems
          Dir[gen_path("gems", '*.gem')].entries.map { |f| File.basename(f) }
        end

        def existing_gemspecs
          Dir[gen_path("quick/Marshal.#{Gem.marshal_version}", '*.rz')].entries.map { |f| File.basename(f) }
        end

        # Fetch a source path under the base uri, and put it in the same or given
        # destination path under the base path.
        def fetch path, etag=nil
          expand_path = gen_path(path)

          [ File.open(expand_path), etag(path) ]
        end

        def etag path
          expand_path = gen_path(path)

          File.exist?(expand_path) ?
            Digest::MD5.hexdigest(File.read(gen_path(path))) :
            nil
        end

        def write(io, path, etag=nil)
          expand_path = gen_path(path)

          FileUtils.mkdir_p File.dirname(expand_path)
          from = io
          to = File.open(expand_path, 'wb')

          IO.copy_stream(from, to)

          from.close
          to.close

          checksum path, etag if etag

          true
        end


        def readonly?
          false
        end

        private

        def gen_path *path
          File.join(base_path, *path)
        end

        def checksum path, etag
          # ETAG not match, delete the file
          if Digest::MD5.hexdigest(File.read(gen_path(path))) != etag.downcase
            File.delete(path)
          end
        end
      end
    end
  end
end
