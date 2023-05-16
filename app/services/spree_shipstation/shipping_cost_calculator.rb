module SpreeShipstation
  class ShippingCostCalculator
    DAILY_STATISTIC_LABEL = 'Shipping'
    class << self
      def update_daily_statistics(from_date, to_date = Date.today)
        data = calculate(from_date, to_date)
        data.each do |date, costs|
          ::Spree::DailyStatistic.update_daily_statistic(date, DAILY_STATISTIC_LABEL, costs, -1)
        end
      end

      def calculate(from_date, to_date = Date.today)
        orders = ::Spree::Order.select(:id, :completed_at).includes(:shipments).completed_between(from_date.to_date.beginning_of_day, to_date.to_date.end_of_day)
        orders.group_by do |order|
          order.completed_at.to_date
        end.map do |date, orders|
          costs = orders.map do |order|
            order.shipments.sum(&:actual_cost)
          end.sum
          [date, costs]
        end.to_h
      end
    end
  end
end