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
        def fetch path, modified_time=nil
          expand_path = gen_path(path)

          File.open(expand_path) do |file|
            yield [file, get_modified_time(expand_path)]
          end
        end

        def get_modified_time path
          expand_path = gen_path(path)

          File.exist?(expand_path) ?
            File.stat(expand_path).mtime.rfc822 :
            nil
        end

        def write(from, path)
          expand_path = gen_path(path)

          FileUtils.mkdir_p File.dirname(expand_path)

          File.open(expand_path, 'wb') do |to|
            IO.copy_stream(from, to)
          end

          true
        end


        def readonly?
          false
        end

        private

        def gen_path *path
          File.join(base_path, *path)
        end
      end
    end
  end
end
