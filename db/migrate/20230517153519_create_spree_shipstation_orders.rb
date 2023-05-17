class CreateSpreeShipstationOrders < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_shipstation_orders do |t|
      t.references :shipment, index: { name: 'shipstation_order_shipment_id_index' }
      t.integer :order_id, default: nil
      t.boolean :needed, default: false

      t.timestamps
    end
  end
end
