module Dashing
  class EventsController < ApplicationController
    include ActionController::Live

    respond_to :html

    def index
      response.headers['Content-Type']      = 'text/event-stream'
      response.headers['X-Accel-Buffering'] = 'no'

      @redis = Dashing.redis
      @redis.psubscribe("#{Dashing.config.redis_namespace}.*") do |on|
        on.pmessage do |pattern, event, data|
          if event == 'parse.new'
            response.stream.write("event: parse\ndata: #{data}\n\n")
          elsif event == 'heartbeat'
            response.stream.write("event: heartbeat\ndata: heartbeat\n\n")
          end
        end
      end
    rescue IOError
      logger.info "[Dashing][#{Time.now.utc.to_s}] Stream closed"
    ensure
      @redis.quit
      response.stream.close
    end
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
end
