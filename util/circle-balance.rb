#!/usr/bin/env ruby

require 'dotenv/load'
require 'circleci'
require 'json'
require 'open-uri'

CircleCi.configure do |config|
  config.token = ENV['CIRCLECI']
end

runtimes = {}
balance = [0, 0, 60, 60]
build = CircleCi::Build.new 'retorquere', 'zotero-better-bibtex', nil, ARGV[0]
build.artifacts.body.each{|artifact|
  next unless File.basename(artifact['path']) == 'runtimes.json'

  cluster = artifact['node_index']
  prefix = (cluster < 2) ? 'zotero' : 'jurism'

  rt = JSON.parse(open(artifact['url']).read)
  rt.keys.each{|k|
    name = "#{prefix}:#{k}"
    rt[name] = rt.delete(k)
    rt[name]['cluster'] = cluster
    balance[cluster] += rt[name]['runtime']
  }

  runtimes = runtimes.merge(rt)
}

puts balance.inspect

if balance.each_with_index.max[1] < 2
  puts 'optimizing for Zotero'
  runtimes.reject!{|k, v| v['cluster'] > 1 }
else
  puts 'optimizing for Juris-M'
  runtimes.reject!{|k, v| v['cluster'] < 2 }
  runtimes.each_pair{|k, v| v['cluster'] -= 2 }
end

balance = [0, 0]

while runtimes.length > 0
  scenario = runtimes.find{|k, v| v['cluster'] == (balance[0] < balance[1] ? 0 : 1) }
  break if scenario.nil?
  name, scenario = scenario

  balance[scenario['cluster']] += scenario['runtime']
  runtimes.delete(name)
end

puts balance.inspect

runtimes.values.each{|test|
  if test['cluster'] % 2 == 0
    move = 'remove'
  else
    move = '   add'
  end
  puts "#{move} @test-cluster-1: #{test['name']}"
}
