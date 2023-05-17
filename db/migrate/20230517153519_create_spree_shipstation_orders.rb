class CreateSpreeShipstationOrders < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_shipstation_orders do |t|
      t.references :shipments, index: { name: 'shipstation_order_shipment_id_index' }
      t.integer :order_id, default: nil

      t.timestamps
    end
  end
end
