module SpreeShipstation
  class UpdateShipstationOrdersJob < ApplicationJob
    queue_as :shipstation

    def perform
      ::Spree::ShipstationAccount.active.each do |shipstation_account|
        syncer = ::SpreeShipstation::ShipmentSyncer.new(shipstation_account)
        ::Spree::ShipstationOrder.where.not(order_key: nil).where(needed: true, is_updated: true, shipstation_account_id: shipstation_account.id).find_in_batches(batch_size: 100) do |shipstation_orders|
          syncer.process_shipstation_orders(shipstation_orders)
          ::Spree::ShipstationOrder.where(id: shipstation_orders.map {|so| so.id }).update_all(is_updated: false)
        end
      end
    end
  end
end
