module SpreeShipstation
  class CleanOrderByShipmentIdJob < ApplicationJob
    queue_as :default

    def perform(shipment_id)
      shipstation_order = ::Spree::ShipstationOrder.where(shipment_id: shipment_id).last
      return if shipstation_order.blank?

      shipstation_account = ::Spree::ShipstationAccount.active.find(shipstation_order.shipstation_account_id)
      SpreeShipstation::ShipmentSyncer.new(shipstation_account).clean_shipment_order_by_id(shipstation_order.order_id) if shipstation_account.present?
    end
  end
end
