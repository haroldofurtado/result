# frozen_string_literal: true

require 'test_helper'

class BCDD::Result::Context::ExpectationsWithSubjectFailureTypeAndValuePatterMatchingErrorTest < Minitest::Test
  class Divide
    include BCDD::Result::Context::Expectations.mixin(
      failure: {
        invalid_arg: ->(value) {
          case value
          in { message: String } then true
          end
        },
        division_by_zero: ->(value) {
          case value
          in { message: String } then true
          end
        }
      }
    )

    def call(arg1, arg2)
      arg1.is_a?(::Numeric) or return Failure(:invalid_arg, message: 'arg1 must be numeric')
      arg2.is_a?(::Numeric) or return Failure(:invalid_arg, message: 'arg2 must not be zero')

      return Failure(:division_by_zero, message: :'arg2 must not be zero') if arg2.zero?

      Success(:division_completed, number: (arg1 / arg2).to_s)
    end
  end

  test 'unexpected value error' do
    err = assert_raises(BCDD::Result::Contract::Error::UnexpectedValue) do
      Divide.new.call(10, 0)
    end

    assert_match(
      Regexp.new(
        'value {:message=>:"arg2 must not be zero"} is not allowed for :division_by_zero type ' \
        '\(cause:.*arg2 must not be zero.*\)'
      ),
      err.message
    )
  end
end
