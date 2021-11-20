class CreateSpreeShipstationAccountStockLocations < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_shipstation_account_stock_locations do |t|
      t.references :shipstation_account, index: { name: 'sasl_shipstation_account_id_index' }
      t.references :stock_location, index: { name: 'sasl_stock_location_id_index' }

      t.timestamps
    end
  end
end
