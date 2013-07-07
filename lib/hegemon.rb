require 'threadlock'

DEBUG = nil

module Hegemon
  # def self.included(base)
  #   base.extend(ClassMethods)
  #   # base.class.instance_variable_get
  #   # base.instance_variable_set(:@dogs, )
  #   base
  # end

  def state;  @_hegemon_state;  end
  def states; @_hegemon_states; end
  
  def impose_state(state); @_hegemon_state = state; end
  
  def declare_state(state, &block)
    @_hegemon_states ||= Hash.new
    @_hegemon_states[state] = HegemonState.new(self, state, &block)
  end
  
end


class HegemonState
  
  attr_reader :state
  
  def initialize(object, state, &block)
    
    @object = object
    @state  = state
    
    puts "In #{@object}, new state :#{@state}." if DEBUG
    
    @transitions = Hash.new
    
    instance_eval(&block)
  end
  
  
  def transition_to(state, &block)
    @transitions[state] = HegemonTransition.new(@object, @state, state, &block)
  end
  
  def transitions; @transitions; end
  
end


class HegemonTransition
  
  attr_reader :src_state, :dest_state
  
  def initialize(object, src_state, dest_state, &block)
    
    @object     = object
    @src_state  = src_state
    @dest_state = dest_state
    
    puts "In #{@object}, new transition from"\
         " :#{@src_state} to #{dest_state}." if DEBUG
    
    @conditions   = []
    @sufficients  = []
    @requirements = []
    @befores      = []
    @afters       = []
    
    @progress = nil
    
    instance_eval(&block)
  end
  
  def condition  (&block);  @conditions   << block;  end
  def sufficient (&block);  @sufficients  << block;  end
  def requirement(&block);  @requirements << block;  end
  def before     (&block);  @befores      << block;  end
  def after      (&block);  @afters       << block;  end
  
  def ready?(*flags)
    return false unless @object.state==@src_state
    return false if @progress
    
    result = (procs_and @requirements)
    return result if (flags.include? :force)
    
    return result && ((procs_or sufficient) or (procs_and @conditions))
  end
  
  def try(*flags)
    (ready?(*flags)) ? 
      (perform; true) :
      (false)
  end
  
private
  
  def perform
    @progress = :pre
    procs_run(@befores)
    @object.impose_state(@dest_state)
    @progress = :post
    procs_run(@afters)
  nil end
  
  def procs_run(list)
    list.each {|proc| @object.instance_eval(&proc) }
  nil end
  
  def procs_and(list)
    list.each {|proc| return false if proc and not @object.instance_eval(&proc)}
  true end
  
  def procs_or(list)
    list.each {|proc| return true if proc and @object.instance_eval(&proc)}
  false end
  
end