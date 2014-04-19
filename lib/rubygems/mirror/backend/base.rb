module Gem
  class Mirror
    module Backend
      class Base
        # Readonly backend cannot be used in Fetcher#to_backend
        def readonly?
          raise NotImplementedError
        end

        # Return or yield a IO instance
        def fetch
          raise NotImplementedError
        end

        def exists?
          raise NotImplementedError
        end

        def existing_gemspecs
          raise NotImplementedError
        end

        def existing_gems
          raise NotImplementedError
        end
      end
    end
  end
end
