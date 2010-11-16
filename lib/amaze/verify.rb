#
# Verify message signature.
#
# TODO: Currently you must manually import key from:
#      http://sns.us-east-1.amazonaws.com/SimpleNotificationService.pem
#
# Then:
#   cert = File.read("SimpleNotificationService.pem")
#   key = OpenSSL::X509::Certificate.new(cert)
#   pk = k.public_key
#
#  Pass `pk` as the second parameter to signature_valid?()
#
require 'openssl'
require 'base64'
require 'json'

module Verify
  def self.signature_valid?(msg, key)
    params = {}
    case msg.class.to_s
    when 'Hash'
      params = msg
    when 'String'
      params = JSON.parse(msg)
    else
      raise "Unknown message format: #{msg.class}"
    end

    raise "Key must be OpenSSL::PKey::RSA" unless key.class == OpenSSL::PKey::RSA
    text = case params['Type']
           when 'Notification'
             canonical_notification(params)
           when 'SubscriptionConfirmation'
             canonical_subscription(params)
           else
             raise "Unknown message type: #{params['Type']}"
           end

    sig = Base64.decode64(params['Signature'])
    key.verify(OpenSSL::Digest::SHA1.new, sig, text)
  end

  def self.canonical_notification(params)
    lines = []
    lines << "Message"
    lines << params['Message']
    lines << "MessageId"
    lines << params['MessageId']
    if params['Subject']
      lines << "Subject"
      lines << params['Subject']
    end
    lines << "Timestamp"
    lines << params['Timestamp']
    lines << "TopicArn"
    lines << params['TopicArn']
    lines << "Type"
    lines << params['Type']
    lines.join("\n") + "\n"
  end

  def self.canonical_subscription(params)
    lines = []
    lines << "Message"
    lines << params['Message']
    lines << "MessageId"
    lines << params['MessageId']
    lines << "SubscribeURL"
    lines << params['SubscribeURL']
    lines << "Timestamp"
    lines << params['Timestamp']
    lines << "Token"
    lines << params['Token']
    lines << "TopicArn"
    lines << params['TopicArn']
    lines << "Type"
    lines << params['Type']
    lines.join("\n") + "\n"
  end
end
