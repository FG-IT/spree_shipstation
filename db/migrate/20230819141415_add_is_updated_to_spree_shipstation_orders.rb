class AddIsUpdatedToSpreeShipstationOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_orders, :is_updated, :boolean, default: false
  end
end
