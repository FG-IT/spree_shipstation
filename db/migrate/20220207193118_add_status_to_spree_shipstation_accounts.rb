class AddStatusToSpreeShipstationAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_accounts, :status, :integer, limit: 2, default: 1
  end
end
