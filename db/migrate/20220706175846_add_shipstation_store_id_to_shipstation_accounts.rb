class AddShipstationStoreIdToShipstationAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_accounts, :shipstation_store_id, :string
  end
end
