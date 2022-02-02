class AddApiKeySecretToSpreeToSpreeShipstationAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_accounts, :api_key, :string
    add_column :spree_shipstation_accounts, :api_secret, :string
  end
end
