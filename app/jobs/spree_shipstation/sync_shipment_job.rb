module SpreeShipstation
  class SyncShipmentJob < ApplicationJob
    queue_as :default

    def perform(order_id)
      shipstation_account = ::Spree::ShipstationAccount.active.first
      SpreeShipstation::ShipmentSyncer.new(shipstation_account).create_shipment_orders
    end
  end
end
