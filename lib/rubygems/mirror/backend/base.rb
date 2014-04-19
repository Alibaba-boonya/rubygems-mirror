module Gem
  class Mirror
    module Backend
      class Base
        # Readonly backend cannot be used in Fetcher#to_backend
        def readonly?
          raise NotImplementedError.new %/override this method "#{__method__}" please/
        end

        # Return or yield a IO instance
        def fetch
          raise NotImplementedError.new %/override this method "#{__method__}" please/
        end

        def exists?
          raise NotImplementedError.new %/override this method "#{__method__}" please/
        end
      end
    end
  end
end
