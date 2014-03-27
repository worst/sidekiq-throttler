require 'spec_helper'
require 'sidekiq/per_process_throttler'

describe Sidekiq::PerProcessThrottler, redis: true do

  subject(:throttler) do
    described_class.new(options)
  end

  let(:worker) do
    LolzWorker.new
  end

  let(:options) do
    { storage: :memory }
  end

  let(:message) do
    {
      args: 'Clint Eastwood'
    }
  end

  let(:queue) do
    # 'per:process:throttler'
    'default'
  end

  let(:redis_class) do
    Sidekiq.redis { |conn| conn.class }
  end

  describe '#call' do

    it 'instantiates a rate limit with the worker, args, and queue' do
      # pending("temporarily disabled")
      puts "queue: #{queue}"
      Sidekiq::Throttler::RateLimit.should_receive(:new).with(
        worker, message['args'], queue, options
      ).and_call_original

      throttler.call(worker, message, queue) {}
    end

    it 'yields in RateLimit#within_bounds' do
      # pending("temporarily disabled")
      expect { |b| throttler.call(worker, message, queue, &b) }.to yield_with_no_args
    end

    it 'calls RateLimit#execute' do
      # pending("temporarily disabled")
      Sidekiq::Throttler::RateLimit.any_instance.should_receive(:execute)
      throttler.call(worker, message, queue)
    end

    context 'when rate limit is exceeded' do

      it 'requeues the job immediately' do
        # pending("...")
        Sidekiq::Throttler::RateLimit.any_instance.should_receive(:exceeded?).and_return(true)
        # worker.class.should_receive(:perform_in).with(1.minute, *message['args'])
        # worker.class.should_receive(:perform).with(*message['args'])
        # Sidekiq::RedisConnection.any_instance.should_receive(:lpush).with("queue:#{queue}", message)

        redis_class.any_instance.should_receive(:lpush).exactly(:once).and_call_original
        throttler.call(worker, message, queue)

        # Sidekiq.redis do |conn|
        #   msgs = conn.lrange("queue:#{queue}", 0, -1)
        #   msgs.size.should eql(1)
        #   puts "msgs: #{msgs}"
        # end

        # sleep(5)
      end
    end
  end
end
