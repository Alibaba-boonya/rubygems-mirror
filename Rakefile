#!/usr/bin/env rake

require 'hoe'
Hoe.plugin :doofus, :git

Hoe.spec 'rubygems-mirror-aliyun' do
  developer('James Tucker', 'raggi@rubyforge.org')

  extra_dev_deps << %w[hoe-doofus ~>1.0]
  extra_dev_deps << %w[hoe-git ~>1.6]
  extra_deps     << %w[net-http-persistent ~>2.9]
  extra_deps     << %w[aliyun-oss]

  self.extra_rdoc_files = FileList["**/*.rdoc"]
  self.history_file     = "CHANGELOG.rdoc"
  self.readme_file      = "README.rdoc"
  self.testlib          = :minitest
end

namespace :aliyun do
  desc "Run the Gem::Aliyun::Command"
  task :update do
    $:.unshift 'lib'
    require 'rubygems/aliyun/command'

    aliyun_mirror = Gem::Commands::AliyunCommand.new
    aliyun_mirror.execute
  end
end

namespace :test do
  task :integration do
    sh Gem.ruby, '-Ilib', '-rubygems', '-S', 'gem', 'mirror'
  end
end
