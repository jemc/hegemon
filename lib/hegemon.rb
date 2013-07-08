require 'threadlock'

Thread.abort_on_exception = true

module Hegemon
  
  #***
  # Accessor functions
  #***
  
  def state;      @_hegemon_state;                   end
  def states;     @_hegemon_states.keys;             end
  def state_obj;  @_hegemon_states[@_hegemon_state]; end
  def state_objs; @_hegemon_states.clone;            end
  
  threadlock :state, :states, :state_obj, :state_objs, :lock=>:@_hegemon_lock
  
  #***
  # Declarative functions
  #***
  # Run these inside of your object's #initialize method
  #  to set the parameters of the state machine
  # All user-provided action blocks will have the scope of the instance object
  #  in which the state machine parameters are initialized, and all parameters
  #  should be initialized in the same place (in #initialize, typically)
  #***
  
  ##
  # :category: Declarative Methods
  #
  # Declare a state in the state machine.
  #
  # [+state+]
  #   The state name to use, as a symbol
  # [+block+]
  #   The state's declarative block.  
  #   All code within gets evaluated not in its original binding,
  #   but in the context of a new HegemonState instance object.  
  #   For stable use, only call methods in this block that are
  #   listed in HegemonState@Declarative+Methods.
  # 
  # The state and associated state machine data and methods will be
  # associated with the object referred to by +self+ object in the context
  # in which the declarative method is called.
  # 
  # This means that in typical usage, the declarative methods listed 
  # in Hegemon@Declarative+Methods (including declare_state) should be 
  # called only from within an instance method, such as +initialize+.
  # 
  # The following example creates a skeleton state machine in each
  # +MyStateMachine+ instance object with two states: +:working+ and +:idle+.
  # 
  #   require 'hegemon'
  #   
  #   class MyStateMachine
  #     include Hegemon
  #     
  #     def initialize
  #       declare_state :working do
  #         # various HegemonState Declarative Methods
  #       end
  #       declare_state :idle do
  #         # various HegemonState Declarative Methods
  #       end
  #     end
  #   end
  # 
  def declare_state(state, &block)
    @_hegemon_states ||= Hash.new
    @_hegemon_states[state] = HegemonState.new(self, state, &block)
  end
  threadlock :declare_state, :lock=>:@_hegemon_lock
  
  
  ##
  # :category: Declarative Methods
  #
  # Bypass all transition requirements and actions to 
  # directly impose state +state+ as the current state.
  #
  # This should *not* be used in the public API *except* to 
  # set the initial state of the state machine, because state changes
  # imposed by impose_state do not obey any rules of the state machine.
  #
  # [+state+]
  #   The state to impose, as a symbol
  #
  # This method should be called in the same scope in which the state
  # was declared with declare_state\.
  # 
  # The following example creates a skeleton state machine in each
  # +MyStateMachine+ instance object with two states: +:working+ and +:idle+
  # and sets +:working+ as the initial state.
  # 
  #   require 'hegemon'
  #   
  #   class MyStateMachine
  #     include Hegemon
  #     
  #     def initialize
  #       impose_state :working
  #       declare_state :working do
  #         # various HegemonState Declarative Methods
  #       end
  #       declare_state :idle do
  #         # various HegemonState Declarative Methods
  #       end
  #     end
  #   end
  def impose_state(s) # :args: state
    @_hegemon_state = s
  end
  threadlock :impose_state, :lock=>:@_hegemon_lock
  
  ##
  # :category: Action Methods
  #
  # Request a transition from the current state to state +state+.
  #
  # [+state+]
  #   The state to which transition is desired, as a symbol
  # [+flags+]
  #   All subsequent arguments are interpreted as flags,
  #   and the only meaningful flag is +:force+ 
  #   (See transition requirements below).
  #
  # In order for the transition to occur, the transition must 
  # have been defined (using HegemonState#transition_to), and the
  # transition rules declared in the transition declarative block
  # have been suitably met by any one of the following situations:
  # * *All* HegemonTransition#requirement blocks evaluate as +true+ 
  #   and the +:force+ flag was included in +flags+.
  # * At least *one* HegemonTransition#sufficient block and *all* 
  #   HegemonTransition#requirement blocks evaluate as +true+
  # * *All* HegemonTransition#condition blocks and *all* 
  #   HegemonTransition#requirement blocks evaluate as +true+
  #
  # Note that evaluation of the rule blocks stops when a match is found,
  # so rule blocks with code that has "side effects" are discouraged.
  #
  def request_state(s, *flags) # :args: state, *flags
    return false unless @_hegemon_states[@_hegemon_state].transitions[s]
    @_hegemon_states[@_hegemon_state].transitions[s].try(*flags)
  end
  threadlock :request_state, :lock=>:@_hegemon_lock
  
  
  # Check for relevant state updates and do.
  #  Using :only_auto flag will ignore all transitions with auto_update false
  def update_state(*flags)
    return false unless @_hegemon_states[@_hegemon_state]
    trans = @_hegemon_states[@_hegemon_state].transitions
    trans = trans.select{|k,t| t.auto_update} if (flags.include? :only_auto)
    trans.each {|k,t| return true if t.try}
  false end
  threadlock :update_state, :lock=>:@_hegemon_lock
  
  def block_until_state(s);
    raise ArgumentError, "Cannot block until undefined state :#{s}" \
      unless @_hegemon_states.keys.include? s
    sleep 0 until @_hegemon_state==s
  end
  
  def do_state_tasks(i=0)
    return nil unless @_hegemon_states[@_hegemon_state]
    @_hegemon_states[@_hegemon_state].do_tasks(i)
  nil end
  threadlock :do_state_tasks, :lock=>:@_hegemon_lock
  
  def iter_hegemon_auto_loop(i=0)
    do_state_tasks(i)
    update_state(:only_auto)
  end
  threadlock :iter_hegemon_auto_loop, :lock=>:@_hegemon_lock
  
  # Run the automatic hegemon thread
  # :args: something, else
  def start_hegemon_auto_thread # :args: flag, dag
    if (not @_hegemon_auto_thread) \
    or (not @_hegemon_auto_thread.status)
      
      @_end_hegemon_auto_thread = false
      @_hegemon_auto_thread = Thread.new do
        i = 0
        until @_end_hegemon_auto_thread
          iter_hegemon_auto_loop(i)
          i += 1
        end
      end
    end
  end
  
  def join_hegemon_auto_thread
    @_hegemon_auto_thread.join if @_hegemon_auto_thread
  end
  
  def end_hegemon_auto_thread
    @_end_hegemon_auto_thread = true
  end
  threadlock :end_hegemon_auto_thread, :lock=>:@_hegemon_lock
end


class HegemonState
  
  attr_reader :state
  
  def initialize(object, state, &block)
    
    raise ScriptError, "HegemonState must be initialized with a block"\
      unless block.is_a? Proc
    
    @object = object
    @state  = state
    
    @tasks       = []
    @transitions = Hash.new
    
    instance_eval(&block)
  end
  
  def task(&block);  @tasks << block if block;  end
  
  def transition_to(state, &block)
    @transitions[state] = HegemonTransition.new(@object, @state, state, &block)
  end
  
  def do_tasks(i=0)
    @tasks.each {|proc| @object.instance_exec(i,&proc) }
  end
  
  def transitions; @transitions; end
  
  threadlock self.instance_methods-Object.instance_methods
  
end


class HegemonTransition
  
  attr_reader :src_state, :dest_state
  
  def initialize(object, src_state, dest_state, &block)
    
    raise ScriptError, "HegemonTransition must be initialized with a block"\
      unless block.is_a? Proc
    
    @object     = object
    @src_state  = src_state
    @dest_state = dest_state
    
    @conditions   = []
    @sufficients  = []
    @requirements = []
    @befores      = []
    @afters       = []
    
    @progress     = nil
    @auto_update  = true
    
    instance_eval(&block)
  end
  
  def condition  (&block);  @conditions   << block if block;  end
  def sufficient (&block);  @sufficients  << block if block;  end
  def requirement(&block);  @requirements << block if block;  end
  def before     (&block);  @befores      << block if block;  end
  def after      (&block);  @afters       << block if block;  end
  
  # Get or set the @auto_update value
  def auto_update(val=:just_ask)
    (val==:just_ask) ?
      (@auto_update) :
      (@auto_update = (true and val))
  end
  
  def ready?(*flags)
    return false unless @object.state==@src_state
    return false if @progress
    
    result = (procs_and @requirements)
    return result if (flags.include? :force)
    
    return result && ((procs_or @sufficients) or (procs_and @conditions))
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
    @progress = :impose
    @object.impose_state(@dest_state)
    @progress = :post
    procs_run(@afters)
    @progress = nil
  nil end
  
  def procs_run(list)
    list.each {|proc| @object.instance_eval(&proc) }
  nil end
  
  def procs_and(list)
    list.each {|proc| return false if not @object.instance_eval(&proc)}
  true end
  
  def procs_or(list)
    list.each {|proc| return true if @object.instance_eval(&proc)}
  false end
  
  threadlock self.instance_methods-Object.instance_methods
  
end