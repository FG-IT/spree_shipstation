module SpreeShipstation
  class SyncShipstationOrderByShipmentIdJob < ApplicationJob
    queue_as :default

    def perform(shipment_ids)
      ::Spree::ShipstationOrder.where(shipment_id: shipment_ids)&.each do |shipstation_order|
        shipstation_account = ::Spree::ShipstationAccount.active.find(shipstation_order.shipstation_account_id)
        SpreeShipstation::ShipmentSyncer.new(shipstation_account).sync_shipstation_order_by_id if shipstation_account.present?
      end
    end
  end
end
