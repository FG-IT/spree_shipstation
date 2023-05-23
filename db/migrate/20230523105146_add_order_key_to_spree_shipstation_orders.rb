class AddOrderKeyToSpreeShipstationOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_orders, :order_key, :string
  end
end
