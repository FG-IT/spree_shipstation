module SpreeShipstation
  class UpdateShipmentJob < ApplicationJob
    queue_as :default

    def perform(shipment_id)
      shipstation_order = ::Spree::ShipstationOrder.find_by(shipment_id: shipment_id)
      if shipstation_order.present?
        shipstation_account = ::Spree::ShipstationAccount.active.find(shipstation_order.shipstation_account_id)
        SpreeShipstation::ShipmentSyncer.new(shipstation_account).update_shipment_orders_by_id(shipstation_order.id)
      end
    end
  end
end
