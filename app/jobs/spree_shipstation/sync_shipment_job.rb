module SpreeShipstation
  class SyncShipmentJob < ApplicationJob
    queue_as :default

    def perform(shipment_ids)
      ::Spree::ShipstationAccount.active.each do |shipstation_account|
        SpreeShipstation::ShipmentSyncer.new(shipstation_account).create_shipment_orders_by_ids(shipment_ids)
      end
    end
  end
end
