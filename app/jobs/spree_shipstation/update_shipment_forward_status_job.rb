module SpreeShipstation
  class UpdateShipmentForwardStatusJob < ApplicationJob
    queue_as :default

    def perform
      SpreeShipstation::ShipmentSyncer.update_shipment_forward_status
    end
  end
end
