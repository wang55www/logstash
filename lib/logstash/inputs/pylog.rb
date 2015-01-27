require 'set'

#pinyou log input
class LogStash::Inputs::Pylog < LogStash::Inputs::Base
  
  config_name "pylog"
  milestone 0
  #log path 
  config :basepath, :validate => :string , :required => true  
  #before how many days
  config :preday , :validate => :number , :default => 1
  
  config :dbpath , :validate => :string , :default => "/tmp"
  
  config :readlast , :validate => :boolean , :default => true
  
  config :interval , :validate => :number , :default => 30
  
  public
  def initialize(params={})
    super(params) 
    @fileHash = Hash.new    #key:timeStr value:Set <FileName>
    @fileDbHash = Hash.new  #key:timeStr  value:File
    @fileHandleSet = Set.new
  end
  
  def timeAgo(baseTime,preday)
    t = baseTime - preday * 60 * 60 *24  
    return t
  end
  
  public 
  def register
    start=Time.new
    #initial @fileHash
    for i in 0..@preday
      timestr=timeAgo(start,i).strftime("%Y%m%d")
      if !@fileHash.has_key?(timestr)
        @fileHash[timestr]=Set.new
      end
      if File.exist?("#@dbpath/#{timestr}.db")
        f=File.open("#@dbpath/#{timestr}.db")
        f.each_line{ |line|
          @fileHash[timestr].add(line)
        }
      end
      
      #readlast is true:put the old logfile into @fileHash
      if @readlast
        Dir["#@basepath/#{timestr}/*/*.log"].each{ |filename|
          fileNameSet=@fileHash[timestr]
          if !(fileNameSet.include?(filename))
            fileNameSet.add(filename)
            # add filename input set
            if !@fileDbHash.has_key?(timestr)
              @fileDbHash[timestr]=File.open("#@dbpath/#{timestr}.db","a+")
            end
            @fileDbHash[timestr].puts "#{filename}"
            #add filename input the db file
          end
        }
      end
    end
  end
  
  #scan new file from the timestr folder
  #and put the new file into @fileHandleSet
  def scanFile(timestr)
    if !@fileHash.has_key?(timestr)
      @fileHash[timestr]=Set.new
    end
    if !@fileDbHash.has_key?(timestr)
      @fileDbHash[timestr]=File.open("#@dbpath/#{timestr}.db","a+")
    end
    Dir["#@basepath/#{timestr}/*/*.log"].each{ |filename|
      fileNameSet=@fileHash[timestr]
      if !(fileNameSet.include?(filename))
        @fileHandleSet.add(filename)
      end
    }    
  end
  
  def clearHash(timeStr)
    
    @fileHash.delete(timeStr)
    @fileDbHash[timeStr].close if @fileDbHash[timeStr]
    @fileDbHash.delete(timeStr)
    
  end
  
  public 
  def run(queue)
    while true
      begin
        start = Time.new
        for i in 0..@preday
          timestr=timeAgo(start,i).strftime("%Y%m%d")
          scanFile(timestr)   
          #found new files and into @fileHandleSet
          @fileHandleSet.each { |filename|
            f=File.open(filename)
            if f
              f.each_line { |line|
                event=LogStash::Event.new
                event["message"]=line
                queue << event
              }
              @fileHash[timestr].add(filename)
              @fileDbHash[timestr].puts(filename)
            end
          } 
          @fileDbHash[timestr].flush
          @fileHandleSet.clear
        end #end for     
        sleep @interval
        
        clearHash(timeAgo(start,@preday+1).strftime("%Y%m%d"))
        clearHash(timeAgo(start,@preday+2).strftime("%Y%m%d"))
        
        rescue EOFError, LogStash::ShutdownSignal
          break
      end  #end begin
    end #end while
    finished
  end

  public
  def teardown
    @fileDbHash.each_value{ |file|
      file.close
    }  
  end
  
end