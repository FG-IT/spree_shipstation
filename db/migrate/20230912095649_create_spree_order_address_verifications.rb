class CreateSpreeOrderAddressVerifications < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_order_address_verifications do |t|
      t.references :order
      t.string :message
      t.boolean :verified, index: true
      t.boolean :residential, index: true
    end
  end
end
