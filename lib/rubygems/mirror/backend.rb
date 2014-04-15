require 'rubygems/mirror/backend/base'

module Gem
  class Mirror
    module Backend
      def self.providers
        {
          :aliyun_oss => "::Gem::Mirror::Backend::AliyunOSS",
          :local      => "::Gem::Mirror::Backend::Local",
          :http       => "::Gem::Mirror::Backend::HTTP"
        }
      end

      def self.new attributes
        attributes = attributes.dup
        provider = attributes.delete("provider").to_s.downcase.to_sym
        if providers.keys.include? provider
          require "rubygems/mirror/backend/#{provider}"
          klass = const_get providers[provider]
          klass.new(attributes)
        else
          raise "Not Supported Provider #{provider}"
        end
      end
    end
  end
end
