class AddExportToShipstationAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_accounts, :export, :boolean, default: false
  end
end
