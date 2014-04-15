module Gem
  class Mirror
    module Backend
      class Base
        # Readonly backend cannot be used in Fetcher#to_backend
        def readonly?
          raise %/override this method "#{__method__}" please/
        end

        # Return a IO instance
        def fetch
          raise %/override this method "#{__method__}" please/
        end

        # Readonly backend doesn't need etag method
        def etag
          unless readonly?
            raise %/override this method "#{__method__}" please/ 
          end
        end

        def exists?
          raise %/override this method "#{__method__}" please/
        end
      end
    end
  end
end
