require "rubygems"
require 'crack/xml'

require File.dirname(__FILE__) + "/helpers"
require File.dirname(__FILE__) + "/exceptions"


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

    resp = http_get("https://#{AmazeSNS.host}/", params)
    handle_resp(resp)
  end

  def handle_resp(resp)
    case resp
    when Net::HTTPForbidden
      raise AuthorizationError
    when Net::HTTPInternalServerError
      raise InternalError
    when Net::HTTPBadRequest
      raise InvalidParameterError
    when Net::HTTPNotFound
      raise NotFoundError
    when Net::HTTPOK
      return resp.body
    else
      raise UnknownError
    end #end case
  end
end
