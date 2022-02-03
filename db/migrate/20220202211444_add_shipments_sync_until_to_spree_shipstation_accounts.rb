class AddShipmentsSyncUntilToSpreeShipstationAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_accounts, :shipments_sync_until, :datetime
  end
end
