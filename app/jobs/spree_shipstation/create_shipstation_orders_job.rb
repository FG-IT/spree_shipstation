module SpreeShipstation
  class CreateShipstationOrdersJob < ApplicationJob
    queue_as :shipstation

    def perform
      ::Spree::ShipstationAccount.active.each do |shipstation_account|
        syncer = ::SpreeShipstation::ShipmentSyncer.new(shipstation_account)
        ::Spree::ShipstationOrder.where(order_key: nil, needed: true, shipstation_account_id: shipstation_account.id).find_in_batches(batch_size: 100) do |shipstation_orders|
          syncer.process_shipstation_orders(shipstation_orders)
        end
      end
    end
  end
end
