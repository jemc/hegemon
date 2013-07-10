require 'threadlock'

Thread.abort_on_exception = true

module Hegemon
  
  ##
  # :section: Accessor Methods
  #
  
  # Return the current state (as a symbol)
  def state;      @_hegemon_state;                   end
  # Return the list of declared states (as an array of symbols)
  def states;     @_hegemon_states.keys;             end
  # Return the current state (as a HegemonState object)
  def state_obj;  @_hegemon_states[@_hegemon_state]; end
  # Return the current state (as a Hash of HegemonState objects keyed by symbol)
  def state_objs; @_hegemon_states.clone;            end
  
  # threadlock :state, :states, :state_obj, :state_objs, :lock=>:@_hegemon_lock
  
  
  
  ##
  # :section: Declarative Methods
  #
  
  #
  # Declare a state in the state machine.  
  # Returns the HegemonState object created.
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
  nil end
  threadlock :impose_state, :lock=>:@_hegemon_lock
  
  
  
  ##
  # :section: State Action Methods
  #
  
  #
  # Request a transition from the current state to state +state+.  
  # Returns +true+ if the transition was performed, else returns +false+.
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
  # transition rules declared in the HegemonTransition declarative block
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
  
  #
  # Check the list of possible transitions from the current state
  # and perform the first transition that is found to be ready, if any.  
  # Returns +true+ if the transition was performed, else returns +false+.
  #
  # [+flags+]
  #   All subsequent arguments are interpreted as flags,
  #   and the only meaningful flag is +:only_auto+.  
  #   Use of the +:only_auto+ flag indicates that all state
  #   transitions which have disabled automatic updating with 
  #   HegemonTransition#auto_update should be ignored.
  # 
  # In order for a transition to occur, the transition rules 
  # declared in the HegemonTransition declarative block have been 
  # suitably met by any one of the following situations:
  # * *All* HegemonTransition#requirement blocks evaluate as +true+ 
  #   and the +:force+ flag was included in +flags+.
  # * At least *one* HegemonTransition#sufficient block and *all* 
  #   HegemonTransition#requirement blocks evaluate as +true+
  # * *All* HegemonTransition#condition blocks and *all* 
  #   HegemonTransition#requirement blocks evaluate as +true+
  #
  def update_state(*flags)
    return false unless @_hegemon_states[@_hegemon_state]
    trans = @_hegemon_states[@_hegemon_state].transitions
    trans = trans.select{|k,t| t.auto_update} if (flags.include? :only_auto)
    trans.each {|k,t| return true if t.try}
  false end
  threadlock :update_state, :lock=>:@_hegemon_lock
  
  #
  # Sleep the current thread until the current state is equal to +state+
  #
  # [+state+]
  #   The symbol to compare against the current state against
  # [+throttle = 0+]
  #   The amount of time to sleep between state checks, 0 by default.
  #
  
  def block_until_state(s, throttle = 0); # :args: state, throttle = 0
    raise ArgumentError, "Cannot block until undefined state :#{s}" \
      unless @_hegemon_states.keys.include? s
    
    @_hegemon_transition_lock ||= Monitor.new
    sleep 0 until @_hegemon_transition_lock.synchronize { @_hegemon_state==s }
  
  nil end
  
  # 
  # Perform all HegemonState#task\s associated with the current state.  
  # Tasks are performed in the order they were declared in the 
  # HegemonState declarative block.
  # 
  # [+iter_num+ = 0]
  #   Specify the iteration number to be passed to the task block.
  #   When called by the +hegemon_auto_thread+ (see start_hegemon_auto_thread),
  #   this number counts up from zero for each iteration of the 
  #   +hegemon_auto_thread+ loop.  If no value is specified, +0+ is used.
  # 
  def do_state_tasks(iter_num = 0)
    return nil unless @_hegemon_states[@_hegemon_state]
    @_hegemon_states[@_hegemon_state].do_tasks(iter_num)
  nil end
  threadlock :do_state_tasks, :lock=>:@_hegemon_lock
  
  
  
  ##
  # :section: Thread Action Methods
  #
  
  def iter_hegemon_auto_loop(i=0)
    do_state_tasks(i)
    update_state(:only_auto)
  end
  private :iter_hegemon_auto_loop
  threadlock :iter_hegemon_auto_loop, :lock=>:@_hegemon_lock
  
  #
  # Run the +hegemon_auto_thread+ if it is not already running.  
  # Returns the Thread object.  
  # The +hegemon_auto_thread+ continually calls do_state_tasks and update_state,
  # counting up from +0+ the value passed to do_state_tasks, until the 
  # thread is stopped with end_hegemon_auto_thread\.
  #
  # [+throttle = nil+]
  #   The amount of time to sleep between iterations.  
  #   If left as nil, the last given throttle value is used.
  #   The default throttle value is 0.05 seconds.
  #
  def start_hegemon_auto_thread(throttle = nil)
    if (not @_hegemon_auto_thread) \
    or (not @_hegemon_auto_thread.status)
      
      @_end_hegemon_auto_thread = false
      @_hegemon_auto_thread_throttle ||= throttle
      @_hegemon_auto_thread_throttle ||= 0.05
      @_hegemon_auto_thread = Thread.new do
        i = 0
        until @_end_hegemon_auto_thread
          iter_hegemon_auto_loop(i)
          i += 1
          sleep @_hegemon_auto_thread_throttle \
            unless @_end_hegemon_auto_thread
        end
      end
    end
    @_hegemon_auto_thread
  end
  
  #
  # Block until the +hegemon_auto_thread+ is finished.
  #
  def join_hegemon_auto_thread
    @_hegemon_auto_thread.join if @_hegemon_auto_thread
  end
  
  #
  # Raise a flag to stop the loop inside +hegemon_auto_thread+.
  # 
  def end_hegemon_auto_thread
    @_end_hegemon_auto_thread = true
    @_hegemon_auto_thread.join unless @_hegemon_auto_thread==Thread.current
    @_hegemon_auto_thread     = nil
  end
  threadlock :end_hegemon_auto_thread, :lock=>:@_hegemon_lock
  
  #
  # :section:
  ##
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
  def setup_task(&block) #TODO
  end
  
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
    
    @object.instance_variable_set(:@_hegemon_transition_lock, 
                                  (@transition_lock = Monitor.new)) \
      unless (@transition_lock = @object.instance_variable_get( \
                                  :@_hegemon_transition_lock))
    
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
    @transition_lock.synchronize do
      @progress = :pre
      procs_run(@befores)
      @progress = :impose
      @object.impose_state(@dest_state)
      @progress = :post
      procs_run(@afters)
      @progress = nil
    end
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