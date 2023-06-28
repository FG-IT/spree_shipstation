module SpreeShipstation
  class SyncShipstationOrderByShipmentIdJob < ApplicationJob
    queue_as :default

    def perform(shipment_id)
      shipstation_order = ::Spree::ShipstationOrder.find_by(shipment_id: shipment_id)
      if shipstation_order.present?
        shipstation_account = ::Spree::ShipstationAccount.active.find(shipstation_order.shipstation_account_id)
        SpreeShipstation::ShipmentSyncer.new(shipstation_account).sync_shipstation_order(shipstation_order) if shipstation_account.present?
      end
    end
  end
end
