module SpreeShipstation
  class UpdateShipmentsJob < ApplicationJob
    queue_as :default

    def perform
      ::Spree::ShipstationAccount.active.each do |shipstation_account|
        SpreeShipstation::ShipmentSyncer.new(shipstation_account).update_shipstation_orders_by_state
      end
    end
  end
end
