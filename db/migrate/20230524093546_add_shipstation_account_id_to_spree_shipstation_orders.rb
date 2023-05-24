class AddShipstationAccountIdToSpreeShipstationOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_orders, :shipstation_account_id, :integer, index: true
  end
end
