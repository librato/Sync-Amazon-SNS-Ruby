require "rubygems"
require 'crack/xml'

require File.dirname(__FILE__) + "/helpers"
require File.dirname(__FILE__) + "/exceptions"

require 'em-http'


class Request
  
  attr_accessor :params, :options
  
  def initialize(params, options={})
    @params = params
    @options = options
  end
  
  def process
    query_string = canonical_querystring(@params)

string_to_sign = "GET
#{AmazeSNS.host}
/
#{query_string}"
                
    hmac = HMAC::SHA256.new(AmazeSNS.skey)
    hmac.update( string_to_sign )
    signature = Base64.encode64(hmac.digest).chomp
    
    params['Signature'] = signature

    unless defined?(EventMachine) && EventMachine.reactor_running?
      raise AmazeSNSRuntimeError, "In order to use this you must be running inside an eventmachine loop"
    end
    
    require 'em-http' unless defined?(EventMachine::HttpRequest)
    
    deferrable = EM::DefaultDeferrable.new
    
    resp = http_class.new("https://#{AmazeSNS.host}/").get(:query => params,
                                                           :timeout => 2)
    resp.callback{
      begin
        success_callback(resp)
        deferrable.succeed
      rescue => e
        deferrable.fail(e)
      end
    }
    resp.errback{
      error_callback(resp)
      deferrable.fail(AmazeSNSRuntimeError.new("A runtime error has occured: status code: #{resp.response_header.status}"))
    }
    deferrable
  end
  
  def http_class
    EventMachine::HttpRequest
  end
  
  
  def success_callback(resp)
    case resp.response_header.status
     when 403
       raise AuthorizationError
     when 500
       raise InternalError
     when 400
       raise InvalidParameterError
     when 404
       raise NotFoundError
     else
       call_user_success_handler(resp)
     end #end case
  end
  
  def call_user_success_handler(resp)
    @options[:on_success].call(resp) if options[:on_success].respond_to?(:call)
  end
  
  def error_callback(resp)
    EventMachine.stop
    raise AmazeSNSRuntimeError.new("A runtime error has occured: status code: #{resp.response_header.status}")
  end
  
  
end
