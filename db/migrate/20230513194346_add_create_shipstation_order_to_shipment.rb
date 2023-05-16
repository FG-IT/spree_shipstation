class AddCreateShipstationOrderToShipment < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipments, :shipstation_order_id, :integer, default: nil
  end
end
