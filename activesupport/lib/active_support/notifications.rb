module ActiveSupport
  # = Notifications
  #
  # +ActiveSupport::Notifications+ provides an instrumentation API for Ruby.
  #
  # == Instrumenters
  #
  # To instrument an event you just need to do:
  #
  #   ActiveSupport::Notifications.instrument("render", :extra => :information) do
  #     render :text => "Foo"
  #   end
  #
  # That executes the block first and notifies all subscribers once done.
  #
  # In the example above "render" is the name of the event, and the rest is called
  # the _payload_. The payload is a mechanism that allows instrumenters to pass
  # extra information to subscribers. Payloads consist of a hash whose contents
  # are arbitrary and generally depend on the event.
  #
  # == Subscribers
  #
  # You can consume those events and the information they provide by registering
  # a subscriber. For instance, let's store all "render" events in an array:
  #
  #   events = []
  #
  #   ActiveSupport::Notifications.subscribe("render") do |*args|
  #     events << ActiveSupport::Notifications::Event.new(*args)
  #   end
  #
  # That code returns right away, you are just subscribing to "render" events.
  # The block will be called asynchronously whenever someone instruments "render":
  #
  #   ActiveSupport::Notifications.instrument("render", :extra => :information) do
  #     render :text => "Foo"
  #   end
  #
  #   event = events.first
  #   event.name      # => "render"
  #   event.duration  # => 10 (in milliseconds)
  #   event.payload   # => { :extra => :information }
  #
  # The block in the +subscribe+ call gets the name of the event, start
  # timestamp, end timestamp, a string with a unique identifier for that event
  # (something like "535801666f04d0298cd6"), and a hash with the payload, in
  # that order.
  #
  # If an exception happens during that particular instrumentation the payload will
  # have a key +:exception+ with an array of two elements as value: a string with
  # the name of the exception class, and the exception message.
  #
  # As the previous example depicts, the class +ActiveSupport::Notifications::Event+
  # is able to take the arguments as they come and provide an object-oriented
  # interface to that data.
  #
  # You can also subscribe to all events whose name matches a certain regexp:
  #
  #   ActiveSupport::Notifications.subscribe(/render/) do |*args|
  #     ...
  #   end
  #
  # and even pass no argument to +subscribe+, in which case you are subscribing
  # to all events.
  #
  # Notifications ships with a queue implementation that consumes and publish events
  # to log subscribers in a thread. You can use any queue implementation you want.
  #
  module Notifications
    autoload :Instrumenter, 'active_support/notifications/instrumenter'
    autoload :Event, 'active_support/notifications/instrumenter'
    autoload :Fanout, 'active_support/notifications/fanout'

    @instrumenters = Hash.new { |h,k| h[k] = notifier.listening?(k) }

    class << self
      attr_accessor :notifier

      def publish(name, *args)
        notifier.publish(name, *args)
      end

      def instrument(name, payload = {})
        if @instrumenters[name]
          instrumenter.instrument(name, payload) { yield payload if block_given? }
        else
          yield payload if block_given?
        end
      end

      def subscribe(*args, &block)
        notifier.subscribe(*args, &block).tap do
          @instrumenters.clear
        end
      end

      def unsubscribe(args)
        notifier.unsubscribe(args)
        @instrumenters.clear
      end

      def instrumenter
        Thread.current[:"instrumentation_#{notifier.object_id}"] ||= Instrumenter.new(notifier)
      end
    end

    self.notifier = Fanout.new
  end
end
