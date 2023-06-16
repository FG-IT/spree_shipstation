module SpreeShipstation
  class SyncShipmentJob < ApplicationJob
    queue_as :default

    def perform(shipstation_account_ids)
      ::Spree::ShipstationAccount.find(shipstation_account_ids)&.each do |shipstation_account|
        SpreeShipstation::SyncShipstationShipmentsJob.perform_later(shipstation_account)
      end
    end
  end
end
