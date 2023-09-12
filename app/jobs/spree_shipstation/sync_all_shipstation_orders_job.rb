module SpreeShipstation
  class SyncAllShipmentOrdersJob < ApplicationJob
    queue_as :shipstation

    def perform
      ::Spree::ShipstationAccount.active.each do |shipstation_account|
        ::SpreeShipstation::ShipmentSyncer.new(shipstation_account).sync_shipment_orders
      end
    end
  end
end