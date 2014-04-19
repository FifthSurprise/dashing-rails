require 'rufus-scheduler'
require 'redis'
require 'connection_pool'

module Dashing
  class Configuration

    attr_reader   :redis
    attr_accessor :redis_host, :redis_port, :redis_password, :redis_namespace
    attr_accessor :auth_token, :devise_allowed_models
    attr_accessor :jobs_path
    attr_accessor :default_dashboard, :dashboards_views_path, :dashboard_layout_path
    attr_accessor :widgets_views_path, :widgets_js_path, :widgets_css_path
    attr_accessor :engine_path, :scheduler

    def initialize
      @engine_path            = '/dashing'
      @scheduler              = ::Rufus::Scheduler.new

      # Redis
      @redis_host             = '127.0.0.1'
      @redis_port             = '6379'
      @redis_password         = nil
      @redis_namespace        = 'dashing_events'

      # Authorization
      @auth_token             = nil
      @devise_allowed_models  = []

      # Jobs
      @jobs_path              = 'app/jobs/'

      # Dashboards
      @default_dashboard      = nil
      @dashboards_views_path  = 'app/views/dashing/dashboards/'
      @dashboard_layout_path  = 'dashing/dashboard'

      # Widgets
      @widgets_views_path     = 'app/views/dashing/widgets/'
      @widgets_js_path        = 'app/assets/javascripts/dashing'
      @widgets_css_path       = 'app/assets/stylesheets/dashing'
    end

    def redis
      @redis ||= ::ConnectionPool::Wrapper.new(size: request_thread_count, timeout: 3) { new_redis_connection }
    end

    def new_redis_connection
      @redis = ::Redis.new(host: redis_host, port: redis_port, password: redis_password)
      heartbeat_thread = Thread.new do
        while true
          @redis.publish("heartbeat","thump")
          sleep 30.seconds
        end
      end

      at_exit do
        # not sure this is needed, but just in case
        heartbeat_thread.kill
        @redis.quit
      end
    end

    private

    def request_thread_count
      if defined?(::Puma) && ::Puma.respond_to?(:cli_config)
        ::Puma.cli_config.options.fetch(:max_threads, 5).to_i
      else
        5
      end
    end
  end
end
