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

class Synchronizer
  def initialize(object)
    @object = object
    @mutex = Mutex.new
  end

  def object
    @object
  end

  def method_missing(method, *args, &block)
    @mutex.synchronize do
      @object.send(method, *args, &block)
    end
  end
end

class Job
  def initialize(input, queue, result)
    @input = input
    @queue = queue
    @result = result
  end

  def execute
    log(@input)
  end

  def log(message)
    puts "#{self.class.name.upcase[0..-4]} #{message}"
  end
end

class ListDirectoryJob < Job
  def execute
    super
    Dir[File.join(@input, '*')].each do |file_or_directory_name|
      @queue << IdentifyPathJob.new(file_or_directory_name, @queue, @result)
    end
  end
end

class IdentifyPathJob < Job
  def execute
    super
    if File.directory?(@input)
      @queue << ListDirectoryJob.new(@input, @queue, @result)
    elsif File.file?(@input)
      ext = File.extname(@input)[1..-1].downcase.to_sym
      @result[ext] ||= []
      @result[ext] << @input
    end
  end
end

result = Synchronizer.new({})
identify_file_queue = WorkQueue.new(8) do |job|
  job.execute
end

puts
start_at = Time.now
identify_file_queue << IdentifyPathJob.new(original_path, identify_file_queue, result)

identify_file_queue.join
puts "Done in #{Time.now - start_at} seconds"

puts
puts result.object.keys.inspect
