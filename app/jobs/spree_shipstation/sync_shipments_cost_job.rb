module SpreeShipstation
  class SyncShipmentsCostJob < ApplicationJob
    queue_as :default

    def perform(shipstation_id)
      shipstation_account = Spree::ShipstationAccount.find(shipstation_id)
      SpreeShipstation::ShipmentSyncer.new(shipstation_account).sync
    end
  end
end