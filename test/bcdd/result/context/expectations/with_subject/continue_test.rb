# frozen_string_literal: true

require 'test_helper'

class BCDD::Result::Context::ExpectationsWithSubjectSuccessTypeTest < Minitest::Test
  class DivideType
    include BCDD::Result::Context::Expectations.mixin(
      with: :Continue,
      success: :ok,
      failure: :err
    )

    def call(arg1, arg2)
      validate_numbers(arg1, arg2)
        .and_then(:validate_non_zero)
        .and_then(:divide)
    end

    private

    def validate_numbers(arg1, arg2)
      arg1.is_a?(::Numeric) or return Failure(:err, message: 'arg1 must be numeric')
      arg2.is_a?(::Numeric) or return Failure(:err, message: 'arg2 must be numeric')

      Continue(number1: arg1, number2: arg2)
    end

    def validate_non_zero(number2:, **)
      number2.zero? ? Failure(:err, 'arg2 must not be zero') : Continue()
    end

    def divide(number1:, number2:)
      Success(:ok, number: number1 / number2)
    end
  end

  class DivideTypes
    include BCDD::Result::Context::Expectations.mixin(
      with: :Continue,
      success: :division_completed,
      failure: %i[invalid_arg division_by_zero]
    )

    def call(arg1, arg2)
      validate_numbers(arg1, arg2)
        .and_then(:validate_non_zero)
        .and_then(:divide)
    end

    private

    def validate_numbers(arg1, arg2)
      arg1.is_a?(::Numeric) or return Failure(:invalid_arg, message: 'arg1 must be numeric')
      arg2.is_a?(::Numeric) or return Failure(:invalid_arg, message: 'arg2 must be numeric')

      Continue(number1: arg1, number2: arg2)
    end

    def validate_non_zero(number2:, **)
      number2.zero? ? Failure(:err, message: 'arg2 must not be zero') : Continue()
    end

    def divide(number1:, number2:)
      Success(:division_completed, number: number1 / number2)
    end
  end

  module DivideTypeAndValue
    extend self, BCDD::Result::Context::Expectations.mixin(
      with: :Continue,
      success: {
        division_completed: ->(value) {
          case value
          in { number: Numeric } then true
          end
        }
      },
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
      validate_numbers(arg1, arg2)
        .and_then(:validate_non_zero)
        .and_then(:divide)
    end

    private

    def validate_numbers(arg1, arg2)
      arg1.is_a?(::Numeric) or return Failure(:invalid_arg, message: 'arg1 must be numeric')
      arg2.is_a?(::Numeric) or return Failure(:invalid_arg, message: 'arg2 must be numeric')

      Continue(number1: arg1, number2: arg2)
    end

    def validate_non_zero(number2:, **input)
      return Failure(:division_by_zero, message: 'arg2 must not be zero') if number2.zero?

      Continue(number2: number2, **input)
    end

    def divide(number1:, number2:)
      Success(:division_completed, number: number1 / number2)
    end
  end

  test 'method chaining using Continue' do
    result1 = DivideType.new.call(10, 2)
    result2 = DivideTypes.new.call(10, 2)
    result3 = DivideTypeAndValue.call(10, 2)

    assert result1.success?(:ok)
    assert result2.success?(:division_completed)
    assert result3.success?(:division_completed)
  end

  test 'type checking' do
    success1 = DivideType.new.call(10, 2)
    success2 = DivideTypes.new.call(10, 2)
    success3 = DivideTypeAndValue.call(10, 2)

    failure1 = DivideType.new.call('10', 0)
    failure2 = DivideTypes.new.call('10', 0)
    failure3 = DivideTypeAndValue.call('10', 0)

    assert_raises(BCDD::Result::Contract::Error::UnexpectedType) { success1.success?(:division_completed) }
    assert_raises(BCDD::Result::Contract::Error::UnexpectedType) { success2.success?(:ok) }
    assert_raises(BCDD::Result::Contract::Error::UnexpectedType) { success3.success?(:ok) }

    assert_raises(BCDD::Result::Contract::Error::UnexpectedType) { failure1.failure?(:invalid_arg) }
    assert_raises(BCDD::Result::Contract::Error::UnexpectedType) { failure2.failure?(:err) }
    assert_raises(BCDD::Result::Contract::Error::UnexpectedType) { failure3.failure?(:err) }
  end
end
