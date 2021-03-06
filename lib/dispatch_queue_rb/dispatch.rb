# =============================================================================
#
# MODULE      : lib/dispatch_queue_rb/dispatch.rb
# PROJECT     : DispatchQueue
# DESCRIPTION :
#
# Copyright (c) 2016, Marc-Antoine Argenton.  All rights reserved.
# =============================================================================

module DispatchQueue
  module Dispatch

    Result = Struct.new( :value )

    class << self
      def ncpu()
        @@ncpu ||= case RUBY_PLATFORM
        when /darwin|freebsd/ then  `sysctl -n hw.ncpu`.to_i
        when /linux/ then           `cat /proc/cpuinfo | grep processor | wc -l`.to_i
        else                        2
        end
      end

      def default_queue
        @@default_queue
      end

      def main_queue
        @@main_queue
      end

      def synchronize()
        mutex, condition = ConditionVariablePool.acquire()
        result = nil
        result_handler = Proc.new { |r|
          result = r;
          mutex.synchronize { condition.signal() }
        }
        mutex.synchronize do
          yield result_handler
          condition.wait( mutex )
        end
        ConditionVariablePool.release( mutex, condition )
        result
      end

      def concurrent_map( input_array, target_queue:nil, &task )
        group = DispatchGroup.new
        target_queue ||= default_queue

        output_results = input_array.map do |e|
          result = Result.new
          target_queue.dispatch_async( group:group ) do
            result.value = task.call( e )
          end
          result
        end

        group.wait()
        output_results.map { |result| result.value }
      end


    private
      @@default_queue = ThreadPoolQueue.new()
      @@main_queue = ThreadQueue.new()

    end # class << self
  end # class Dispatch
end # module DispatchQueue
