module SpreeShipstation
  class PrepareShipstationOrdersJob < ApplicationJob
    queue_as :shipstation

    def perform(shipstation_order_ids)
      shipstation_orders = ::Spree::ShipstationOrder.where(id: shipstation_order_ids)
      shipstation_orders_mapping = ::Hash[ shipstation_orders.map {|so| [so.id, so] } ]
      ::Spree::ShipstationOrder.shipstation_orders_data(shipstation_orders).each do |shipstation_order_id, sod|
        next if sod.blank?

        shipstation_order = shipstation_orders_mapping[shipstation_order_id]
        sha = ::Digest::SHA1.hexdigest(JSON.generate(sod))
        sha_current = shipstation_order.data.present? ? ::Digest::SHA1.hexdigest(shipstation_order.data) : ''
        if sha != sha_current
          shipstation_order.data = JSON.generate(sod)
          shipstation_order.is_updated = true
          shipstation_order.save
        end
      end
    end
  end
end
