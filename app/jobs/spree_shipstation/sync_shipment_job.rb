module SpreeShipstation
  class SyncShipmentJob < ApplicationJob
    queue_as :default

    def perform
      ::Spree::ShipstationAccount.active.each do |shipstation_account|
        SpreeShipstation::ShipmentSyncer.new(shipstation_account).create_shipment_orders
      end
    end
  end
end
