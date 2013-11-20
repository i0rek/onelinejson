require "onelinejson/version"
require 'json'
require 'lograge'

require 'active_support/core_ext/class/attribute'
require 'active_support/log_subscriber'

module Onelinejson
  module AppControllerMethods
    def append_info_to_payload(payload)
      super
      headers = if request.headers.respond_to?(:env)
        request.headers.env
      elsif request.headers.respond_to?(:to_hash)
        request.headers.to_hash
      end.reject {|k, v| !k.starts_with?("HTTP_") || k == "HTTP_AUTHORIZATION"}

      payload[:request] = {
        params: params.reject { |k,v|
          k == 'controller' || k == 'action' || v.is_a?(ActionDispatch::Http::UploadedFile)
        },
        headers: headers,
        ip: request.ip,
        uuid: request.env['action_dispatch.request_id'],
        controller: self.class.name,
        date: Time.now.utc.iso8601,
      }
      payload[:request][:user_id] = current_user.id if defined?(current_user) && current_user

    end
  end

  class Railtie < Rails::Railtie
    config.lograge = ActiveSupport::OrderedOptions.new
    config.lograge.formatter = ::Lograge::Formatters::Json.new
    config.lograge.enabled = true
    config.lograge.before_format = lambda do |data, payload|
      data.merge(payload)
      request = payload[:request].merge(data.select{ |k,_|
        [:method, :path, :format, :controller, :action].include?(k)
      })
      response = data.select{ |k,_|
        [:status, :duration, :view, :view_runtime].include?(k)
      }
      Hash[{
        request: request,
        response: response,
        debug_info: payload[:debug_info]
      }.sort]
    end
    ActiveSupport.on_load(:action_controller) do
      include AppControllerMethods
    end
  end
end
