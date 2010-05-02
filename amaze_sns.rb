require "rubygems"
require 'logger'

require "topic"
require "helpers"
require "request"
require "exceptions"
require "eventmachine"
require 'crack/xml'

class AmazeSNS
  
  class CredentialError < ::ArgumentError
    def message
      'Please provide your Amazon keys to use the service'
    end
  end
  
  class << self
    attr_accessor :host, :logger, :topics, :skey, :akey
    #attr_writer :skey, :akey
  end

  
  self.host = 'sns.us-east-1.amazonaws.com'
  self.logger = Logger.new($STDOUT)
  self.skey = ''
  self.akey=''
  self.topics ||= {}
  
  def self.[](topic)
    raise CredentialError unless (!(@skey.empty?) && !(@akey.empty?))
    @topics[topic.to_s] = Topic.new(topic) unless @topics.has_key?(topic)
    @topics[topic.to_s]
  end
  
  #method to refresh the topics hash so as to cut down calls to SNS
  def self.refresh_list(reload={})
    
    @results = Array.new
   
    EM.run do
      self.list_topics do |response|
        #p "INSIDE EM LOOP"
        parsed_response = Crack::XML.parse(response.response)
        #p "PARSED RESPONSE: #{parsed_response.inspect}"
        @results = parsed_response["ListTopicsResponse"]["ListTopicsResult"]["Topics"]["member"]
        EM.stop
      end
    end # end EM loop
   

    @results.each do|t|
      label = t["TopicArn"].split(':').last.to_s
      unless @topics.has_key?(label)
        @topics[label] = Topic.new(label,t["TopicArn"])
      else
        @topics[label].arn = t["TopicArn"]
      end
    end
    
  end

  def self.list_topics(&blk)
    #p "INSIDE LIST TOPICS"
    # TESTING LIST TOPICS

    params = {
      'Action' => 'ListTopics',
      'SignatureMethod' => 'HmacSHA256',
      'SignatureVersion' => 2,
      'Timestamp' => Time.now.iso8601,
      'AWSAccessKeyId' => @akey
    }
    req_options={}
    req_options[:on_success] = blk if blk
    req = Request.new(params, req_options).process
  end
  
  def self.list_topics2
    #p "INSIDE LIST TOPICS"
    # TESTING LIST TOPICS

    params = {
      'Action' => 'ListTopics',
      'SignatureMethod' => 'HmacSHA256',
      'SignatureVersion' => 2,
      'Timestamp' => Time.now.iso8601,
      'AWSAccessKeyId' => @akey
    }

    req = Request.new(params)
    response = req.process2
      
    # this returns list of topics in the following format:
    # "{\"ListTopicsResponse\"=>{\"ListTopicsResult\"=>{\"Topics\"=>{\"member\"=>[{\"TopicArn\"=>\"arn:aws:sns:us-east-1:365155214602:Manamana\"}, {\"TopicArn\"=>\"arn:aws:sns:us-east-1:365155214602:smellycats\"}, {\"TopicArn\"=>\"arn:aws:sns:us-east-1:365155214602:29steps_products\"}]}}, \"ResponseMetadata\"=>{\"RequestId\"=>\"d96bd22e-4e01-11df-a8c4-6be3d4c10820\"}, \"xmlns\"=>\"http://sns.amazonaws.com/doc/2010-03-31/\"}}"
    # need to grab just the member array from the hash to retur it
    arr = response["ListTopicsResponse"]["ListTopicsResult"]["Topics"]["member"]
    return arr
  end
  
  
  # grabs all the subscriptions
  def self.subscriptions
    
  end
  
  
end