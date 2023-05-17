module SpreeShipstation
  class SyncShipmentJob < ApplicationJob
    queue_as :default

    def perform
      shipstation_account = ::Spree::ShipstationAccount.where(username: 'everymarket').last
      SpreeShipstation::ShipmentSyncer.new(shipstation_account).create_shipment_orders if shipstation_account.present?
    end
  end
end
