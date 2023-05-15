class AddCreateShipstationOrderToShipment < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipments, :create_shipstation_order, :boolean, default: false
  end
end
