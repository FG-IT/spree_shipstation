class AddStoreIdsToSpreeShipstationAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_accounts, :store_ids, :text
  end
end
