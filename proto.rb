#!/usr/bin/env ruby

require 'thread/pool'
require 'pp'

if ARGV.length == 0
  puts "Usage: proto.rb <file_or_directory_name>"
  exit 1
end

original_path = ARGV[0].sub(/\/$/, '')
if original_path !~ /^\//
  original_path = File.expand_path(original_path)
end

puts "Called with #{original_path}"

class Synchronizer
  attr_reader :object

  def initialize(object)
    @object = object
    @mutex = Mutex.new
  end

  def method_missing(method, *args, &block)
    @mutex.synchronize do
      @object.send(method, *args, &block)
    end
  end
end

class DifferedWorkQueue
  def initialize(count = 4, &block)
    @count = count
    @block = block
    @jobs = []
  end

  def <<(*args)
    @jobs << args
  end

  def join
    @queue = WorkQueue.new(@count, &@block)
    @jobs.each do |job|
      @queue << job
    end
    @queue.join
  end
end

class WorkQueue
  def initialize(initial_output, count = 4, &block)
    @count = count
    @output = Synchronizer.new(initial_output)
    @block = block
  end

  def enqueue(input, &block)
    (@pool ||= Thread.pool(@count)).process do
      if block_given?
        block.call(input, self, @output)
      else
        @block.call(input, self, @output)
      end
    end
  end

  def join
    @pool.wait_done if @pool
    @output.object
  end
end

class Job
  def initialize(input)
    @input = input
  end

  def execute(queue, output)
    # do nothing by default
  end
end

class ListDirectoryJob < Job
  def execute(queue, output)
    Dir[File.join(@input, '*')].each do |file_or_directory_name|
      queue.enqueue(IdentifyPathJob.new(file_or_directory_name))
    end
  end
end

class IdentifyPathJob < Job
  def execute(queue, output)
    if File.directory?(@input)
      queue.enqueue(ListDirectoryJob.new(@input))
    elsif File.file?(@input)
      ext = File.extname(@input)[1..-1].downcase.to_sym
      output[ext] ||= []
      output[ext] << @input
    end
  end
end

main_queue = WorkQueue.new({}) do |input, queue, output|
  input.execute(queue, output)
end

puts
puts "Executing main queue"
start_at = Time.now
main_queue.enqueue(IdentifyPathJob.new(original_path))
result = main_queue.join
puts "Done in #{Time.now - start_at} seconds"

puts
result.each do |ext, files|
  puts ext
  files.each do |file|
    puts "  #{file}"
  end
end
