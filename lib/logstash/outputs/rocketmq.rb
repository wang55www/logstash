require "logstash/outputs/base"
require "logstash/namespace"
require "logstash/outputs/rocketmq/rocketmq-client-3.1.1"
require "logstash/outputs/rocketmq/rocketmq-common-3.1.1"
require "logstash/outputs/rocketmq/rocketmq-remoting-3.1.1"
require "logstash/outputs/rocketmq/slf4j-api-1.7.5"
require "logstash/outputs/rocketmq/logback-classic-1.0.13"
require "logstash/outputs/rocketmq/logback-core-1.0.13"
require "logstash/outputs/rocketmq/fastjson-1.1.41"
require "logstash/outputs/rocketmq/gson-2.2.1"
require "logstash/outputs/rocketmq/netty-all-4.0.19.Final"
java_import "com.alibaba.rocketmq.client.producer.DefaultMQProducer"
java_import "com.alibaba.rocketmq.common.message.Message"
java_import "com.alibaba.rocketmq.client.producer.SendStatus"

class LogStash::Outputs::Rocketmq < LogStash::Outputs::Base

  @@counter=0

  config_name "rocketmq"
  milestone 0
  
  #rocketmq nameserver
  config :namesrv, :validate => :string, :required => true
  
  #rocketmq topic
  config :topic, :validate => :string, :required => true
  
  config :producer_group, :validate => :string, :required => true
  
  #set send oneway flag,client don't wait for reply from server
  config :oneway, :validate => :boolean, :default => false
  
  #if the size of the message over maxbody,will compress the body of message
  config :maxbody, :validate => :number, :default => 512
  
  config :showtimeflag, :validate => :boolean, :default => true
  
  config :intervalnum, :validate => :number, :default => 1000000
  
  public
  def register
    @producer=DefaultMQProducer.new @producer_group
    @producer.setNamesrvAddr @namesrv
    @producer.setCompressMsgBodyOverHowmuch @maxbody
    @producer.start
    puts "rocketmq register done"
  end
  
  def receive(event)
    return unless output?(event)
    
    if event == LogStash::SHUTDOWN
      @producer.shutdown
      finished
      return
    end
    
    @@counter += 1
    
    key = event.sprintf(@key) if @key
    
    logstr=java.lang.String.new(event["message"])
    
    mess=Message.new(@topic,logstr.getBytes)
    
    if @showtimeflag&&@@counter==@intervalnum 
      puts logstr.split("\t")[6]
      @@counter=0
    end
    
    if @oneway
      @producer.sendOneway(mess)
    elsif
      for i in 0..4  #0 1 2 3 4 five times
        result=@producer.send(mess)
        if result.getSendStatus == SendStatus::SEND_OK
          break;
        end
      end
    end 

  end
  
end