require_relative 'lib/hegemon'

# DEBUG = true

class A
  include Hegemon
  
  attr_accessor :dog
  
  def initialize
    
    @dog = false
    
    impose_state :alive
    
    declare_state(:alive) do
      
      task do
        sleep 0
        $abc||=0
        $abc+=1
        # puts "I'm alive! #{iter}"
      end
    
      transition_to :dying do
        
        # auto_update false
        
        condition {@dog}
        condition {true}
        
        requirement {true}
        
        sufficient {true==false}
        
        before do
          puts "goodbye, :#{state}"
        end
        
        after do
          puts "hello, :#{state}"
        end
        
      end
    end
    
    start_hegemon_auto_thread
  
  end
  
end

a = A.new
a.dog=true

sleep 0.2
