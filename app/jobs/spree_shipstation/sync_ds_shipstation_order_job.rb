module SpreeShipstation
  class SyncDsShimpstationOrderJob < ApplicationJob
    queue_as :default

    def perform

      shipstation_account = ::Spree::ShipstationAccount.active.where(name: 'EM DS').last

      SpreeShipstation::ShipmentSyncer.new(shipstation_account).create_shipment_orders
    end
  end
end
