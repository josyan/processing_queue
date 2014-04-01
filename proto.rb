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
  def initialize(count = 4, &block)
    @pool = Thread.pool(count)
    @block = block
  end

  def <<(*args)
    @pool.process do
      @block.call(*args)
    end
  end

  def join
    @pool.wait_done
  end
end

class ResultQueue
  def initialize
    @queue = []
    @mutex = Mutex.new
  end

  def <<(*args)
    @mutex.synchronize do
      args.each do |a|
        @queue << a
      end
    end
  end

  def result
    @queue
  end
end

result_queue = ResultQueue.new
identify_file_queue = WorkQueue.new(10) do |i|
  puts "START #{i}"
  result_queue << i
  sleep(rand)
  if rand < 0.5
    identify_file_queue << i + 100
  end
  puts "STOP  #{i}"
end

100.times do |i|
  identify_file_queue << i
end
puts "ALL JOBS ADDED"

identify_file_queue.join
puts "ALL JOBS DONE"

puts result_queue.result.sort.join(',')
