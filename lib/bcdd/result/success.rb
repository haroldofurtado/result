# frozen_string_literal: true

module BCDD::Result
  class Success < Base
    def success?(type = nil)
      type.nil? || type == self.type
    end

    def failure?(_type = nil)
      false
    end

    def value_or
      value
    end
  end
end