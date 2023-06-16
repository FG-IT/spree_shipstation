module SpreeShipstation
  class SyncShipstationShipmentsJob < ApplicationJob
    queue_as :default

    def perform(shipstation_account)
      SpreeShipstation::ShipmentSyncer.new(shipstation_account).create_shipment_orders
    end
  end
end
