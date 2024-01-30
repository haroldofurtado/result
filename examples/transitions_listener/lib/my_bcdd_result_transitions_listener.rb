# frozen_string_literal: true

class MyBCDDResultTransitionsListener
  include BCDD::Result::Transitions::Listener

  # A listener will be initialized before the first transition, and it is discarded after the last one.
  def initialize
    @buffer = []
  end

  # This method will be called before each transition block.
  # The parent transition block will be called first in the case of nested transition blocks.
  #
  # @param scope: {:id=>1, :name=>"SomeOperation", :desc=>"Optional description"}
  def on_start(scope:)
    scope => { id:, name:, desc: }

    @buffer << [id, "##{id} #{name} - #{desc}".chomp('- ')]
  end

  # This method will wrap all the transitions in the same block.
  # It can be used to perform an instrumentation (measure/report) of the transitions.
  #
  # @param scope: {:id=>1, :name=>"SomeOperation", :desc=>"Optional description"}
  def around_transitions(scope:)
    yield
  end

  # This method will wrap each and_then call.
  # It can be used to perform an instrumentation (measure/report) of the and_then calls.
  #
  # @param scope: {:id=>1, :name=>"SomeOperation", :desc=>"Optional description"}
  # @param and_then:
  #  {:type=>:block, :arg=>:some_injected_value}
  #  {:type=>:method, :arg=>:some_injected_value, :method_name=>:some_method_name}
  def around_and_then(scope:, and_then:)
    yield
  end

  # This method will be called after each result recording/tracking.
  #
  # @param record:
  # {
  #   :root => {:id=>0, :name=>"RootOperation", :desc=>nil},
  #   :parent => {:id=>0, :name=>"RootOperation", :desc=>nil},
  #   :current => {:id=>1, :name=>"SomeOperation", :desc=>nil},
  #   :result => {:kind=>:success, :type=>:continued, :value=>{some: :thing}, :source=><MyProcess:0x0000000102fd6378>},
  #   :and_then => {:type=>:method, :arg=>nil, :method_name=>:some_method},
  #   :time => 2024-01-26 02:53:11.310431 UTC
  # }
  def on_record(record:)
    record => { current: { id: }, result: { kind:, type: } }

    method_name = record.dig(:and_then, :method_name)

    @buffer << [id, " * #{kind}(#{type}) from method: #{method_name}".chomp('from method: ')]
  end

  MapNestedMessages = ->(transitions, buffer, hide_given_and_continued) do
    ids_matrix = transitions.dig(:metadata, :ids_matrix)

    messages = buffer.filter_map { |(id, msg)| "#{'   ' * ids_matrix[id].last}#{msg}" if ids_matrix[id] }

    messages.reject! { _1.match?(/\(given|continued\)/) } if hide_given_and_continued

    messages
  end

  # This method will be called at the end of the transitions tracking.
  #
  # @param transitions:
  # {
  #   :version => 1,
  #   :metadata => {
  #     :duration => 0,
  #     :trace_id => nil,
  #     :ids_tree => [0, [[1, []], [2, []]]],
  #     :ids_matrix => {0 => [0, 0], 1 => [1, 1], 2 => [2, 1]}
  #   },
  #   :records => [
  #     # ...
  #   ]
  # }
  def on_finish(transitions:)
    messages = MapNestedMessages[transitions, @buffer, ENV['HIDE_GIVEN_AND_CONTINUED']]

    puts messages.join("\n")
  end

  # This method will be called when an exception is raised during the transitions tracking.
  #
  # @param exception: Exception
  # @param transitions: Hash
  def before_interruption(exception:, transitions:)
    messages = MapNestedMessages[transitions, @buffer, ENV['HIDE_GIVEN_AND_CONTINUED']]

    puts messages.join("\n")

    bc = ::ActiveSupport::BacktraceCleaner.new
    bc.add_filter { |line| line.gsub(__dir__.sub('/lib', ''), '').sub(/\A\//, '')}
    bc.add_silencer { |line| /lib\/bcdd\/result/.match?(line) }
    bc.add_silencer { |line| line.include?(RUBY_VERSION) }

    backtrace = bc.clean(exception.backtrace)

    puts "\nException: #{exception.message} (#{exception.class}); Backtrace: #{backtrace.join(", ")}"
  end
end
