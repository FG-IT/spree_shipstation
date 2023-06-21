module SpreeShipstation
  class SyncShipmentJob < ApplicationJob
    queue_as :default

    def perform(shipment_id)
      shipstation_order = ::Spree::ShipstationOrder.find_by(shipment_id: shipment_id)
      shipstation_account = ::Spree::ShipstationAccount.active.find(shipstation_order.shipstation_account_id)
      SpreeShipstation::ShipmentSyncer.new(shipstation_account).create_shipment_order_by_id(shipment_id) if shipstation_account
    end
  end
end
