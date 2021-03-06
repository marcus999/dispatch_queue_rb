# =============================================================================
#
# MODULE      : lib/dispatch_queue_rb/dispatch_group.rb
# PROJECT     : DispatchQueue
# DESCRIPTION :
#
# Copyright (c) 2016, Marc-Antoine Argenton.  All rights reserved.
# =============================================================================

module DispatchQueue
  class DispatchGroup
    def initialize()
      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @count = 0
      @notify_list = []
    end

    def enter()
      @mutex.synchronize { @count += 1 }
      self
    end

    def leave()
      notify_list = @mutex.synchronize do
        @count -= 1
        raise "Unbalanced calls to DispatchGroup.enter() / .leave()" if @count < 0
        if @count == 0
          @condition.broadcast()
          _sync_swap_notify_list()
        end
      end

      _schedule_notify_list( notify_list ) if notify_list
      self
    end

    def notify( target_queue:nil, barrier:false, group:nil, &task )
      continuation = Continuation.new( target_queue:target_queue,
                                       barrier:barrier, group:group, &task )
      @mutex.synchronize do
        if @count == 0
          continuation.run( default_target_queue:Dispatch.default_queue )
        else
          @notify_list << continuation
        end
      end
      self
    end

    def wait( timeout:nil )
      @mutex.synchronize do
        return true if @count == 0
        @condition.wait( @mutex, timeout )
        return @count == 0
      end
    end

  private
    def _sync_swap_notify_list()
      return nil if @notify_list.empty?
      notify_list = @notify_list
      @notify_list = []
      return notify_list
    end

    def _schedule_notify_list( notify_list )
      notify_list.each { |continuation| continuation.run() }
    end

  end # class DispatchGroup
end # module DispatchQueue
