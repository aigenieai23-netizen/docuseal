# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Sends mail via the Resend HTTPS API instead of SMTP.
# Railway's Hobby plan blocks all outbound SMTP ports (25/465/587),
# so SMTP delivery cannot work there. This uses port 443 (HTTPS) instead.
class ResendDeliveryMethod
  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    uri = URI('https://api.resend.com/emails')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@settings[:api_key]}"
    request['Content-Type'] = 'application/json'

    payload = {
      from: mail[:from].to_s,
      to: Array(mail.to),
      subject: mail.subject,
      html: (mail.html_part ? mail.html_part.body.decoded : (mail.content_type.to_s.include?('html') ? mail.body.decoded : nil)),
      text: (mail.text_part ? mail.text_part.body.decoded : (mail.content_type.to_s.include?('html') ? nil : mail.body.decoded))
    }.compact

    request.body = payload.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Resend API delivery failed: #{response.code} #{response.body}"
    end

    response
  end
end

ActionMailer::Base.add_delivery_method :resend, ResendDeliveryMethod
