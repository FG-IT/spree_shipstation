module SpreeShipstation
  class UpdateDsShipstationOrdersJob < ApplicationJob
    queue_as :default

    def perform
      shipstation_account = ::Spree::ShipstationAccount.active.where(name: 'EM DS').last
      SpreeShipstation::ShipmentSyncer.new(shipstation_account).update_shipment_orders_by_date(12)
    end
  end
end
