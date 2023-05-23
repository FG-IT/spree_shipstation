class AddSkusToSpreeShipstationAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_accounts, :skus, :string
  end
end
