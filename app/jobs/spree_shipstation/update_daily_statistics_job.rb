module SpreeShipstation
  class UpdateDailyStatisticsJob < ApplicationJob
    queue_as :default

    def perform
      possibility = rand()
      if possibility > 0.95
        from_date = 60.days.ago
      elsif possibility > 0.8
        from_date = 30.days.ago
      else
        from_date = 7.days.ago
      end
      SpreeShipstation::ShippingCostCalculator.update_daily_statistics(from_date)
    end

  end
end