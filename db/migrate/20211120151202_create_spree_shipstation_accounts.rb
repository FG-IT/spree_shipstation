class CreateSpreeShipstationAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_shipstation_accounts do |t|
      t.string :username
      t.string :password

      t.timestamps
    end
  end
end
