require_relative 'lib/hegemon'

# DEBUG = true

class A
  include Hegemon
  
  attr_accessor :dog
  
  def initialize
    
    @dog = false
    
    
    
    impose_state :alive
    
    declare_state :alive do
    
      transition_to :dying do
        
        condition do
          @dog
        end
        
        condition do
          true
        end
        
        requirement do
          true
        end
        
        sufficient do
          true==false
        end
        
        before do
          puts "goodbye, :#{state}"
        end
        
        after do
          puts "hallo, :#{state}"
        end
        
      end
    end
  
  end
  
end

# h = Hash.new
# h['dog']='woof'
# p h.keys

a = A.new
p a.states[:alive].transitions[:dying].ready?
p a.states[:alive].transitions[:dying].ready? :force
a.dog=true
p a.states[:alive].transitions[:dying].ready?
p a.state
p a.states[:alive].transitions[:dying].try
p a.state