class AddNameToSpreeShipstationAccount < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_accounts, :name, :string
  end
end
