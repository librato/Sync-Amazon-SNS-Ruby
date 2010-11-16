require "rubygems"
require 'crack/xml'

require File.dirname(__FILE__) + "/helpers"
require File.dirname(__FILE__) + "/exceptions"

require 'em-http'


class Request

  attr_accessor :params

  def initialize(params)
    @params = params
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
        success_callback(resp, deferrable)
      rescue => e
        deferrable.fail(e)
      end
    }
    resp.errback{
      error_callback(resp, deferrable)
    }
    deferrable
  end

  def http_class
    EventMachine::HttpRequest
  end

  def success_callback(resp, dfr)
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
       dfr.succeed(resp)
     end #end case
  end

  def error_callback(resp, dfr)
    # Most likely a timeout if we get here. Anything valid in the response?
    errmsg = "A runtime error has occurred. Timeout?"
    dfr.fail(AmazeSNSRuntimeError.new(errmsg))
  end
end
