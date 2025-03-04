module Admin
  class StatsController < Admin::ApplicationController
    before_action :with_variant, only: %i[index]
    before_action :skip_policy_scope, only: %i[index]

    def index
      @stats = {
        customer_count: Customer.count,
        order_count: Order.count
      }
    end

    private

    def with_variant
      if @current_user.admin?
        request.variant = :admin
      end
    end
  end
end
