#!/usr/bin/env ruby

require 'thread/pool'

if ARGV.length == 0
  puts "Usage: proto.rb <file_or_directory_name>"
  exit 1
end

original_path = ARGV[0].sub(/\/$/, '')
if original_path !~ /^\//
  original_path = File.expand_path(original_path)
end

puts "Called with #{original_path}"

class WorkQueue
  def initialize(count = 4)
    @threads = []
    @pool = Thread.pool(count)
  end

  def <<(file_path)
    @threads << Thread.new do
      @pool.process do
        call(file_path)
      end
    end
  end

  def call(file_path)
    puts "START #{file_path}"
    sleep(rand)
    puts "STOP  #{file_path}"
  end

  def join
    @threads.each { |thr| thr.join }
    @pool.wait_done
  end
end

puts ""
identify_file_queue = WorkQueue.new
100.times do |i|
  identify_file_queue << i
end
puts "ALL JOBS ADDED"

identify_file_queue.join
puts "ALL JOBS DONE"
