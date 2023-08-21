module SpreeShipstation
  class SyncAllShipmentsCostJob < ApplicationJob
    queue_as :shipstation

    def perform
      Spree::ShipstationAccount.active.pluck(:id).each do |shipstation_id|
        SpreeShipstation::SyncShipmentsCostJob.perform_later(shipstation_id)
      end
    end
  end
end