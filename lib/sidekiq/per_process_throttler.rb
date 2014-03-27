require 'sidekiq'
require 'active_support/core_ext/numeric/time'
require 'singleton'

require 'sidekiq/throttler/version'
require 'sidekiq/throttler/rate_limit'

require 'sidekiq/throttler/storage/memory'
require 'sidekiq/throttler/storage/redis'

module Sidekiq
  ##
  # Sidekiq server middleware. Throttles jobs when they exceed limits specified
  # on the worker. Jobs that exceed the limit are requeued immediately.
  #
  # TODO: This will only work with in memory storage right now. To deal with
  # storage in redis will be a bit more complicated because each process needs
  # its own limit count instead of just one per worker class.
  class PerProcessThrottler < Sidekiq::Throttler
    def initialize(options = {})
      # @options = options.dup
      super(options)
    end

    ##
    # Passes the worker, arguments, and queue to {RateLimit} and either yields
    # or requeues the job  immediately depending on whether the worker is
    # throttled.
    #
    # TODO: Allow for a limit on the number of times this job can be requeued
    # Ideally, this would track all processes that have requeued the job and
    # then sum over them (or something).
    #
    # @param [Sidekiq::Worker] worker
    #   The worker the job belongs to.
    #
    # @param [Hash] msg
    #   The job message.
    #
    # @param [String] queue
    #   The current queue.
    def call(worker, msg, queue)
      rate_limit = RateLimit.new(worker, msg['args'], queue, @options)

      rate_limit.within_bounds do
        yield
      end

      rate_limit.exceeded do
        Sidekiq.redis do |conn|
          # msg["requeued_count"] ||= 0
          # msg["requeued_count"] += 1
          conn.lpush("queue:#{queue}", msg)
          nil
        end
      end

      rate_limit.execute
    end

  end # PerProcessThrottler
end # Sidekiq
