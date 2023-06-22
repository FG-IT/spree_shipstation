module SpreeShipstation
  class UpdateShipmentsByAccountJob < ApplicationJob
    queue_as :default

    def perform
      ::Spree::ShipstationAccount.active.each do |shipstation_account|
        SpreeShipstation::ShipmentSyncer.new(shipstation_account).update_shipment_orders_by_date(12)
      end
    end
  end
end
