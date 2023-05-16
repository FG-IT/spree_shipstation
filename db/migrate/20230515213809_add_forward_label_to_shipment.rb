class AddForwardLabelToShipment < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipments, :forward, :boolean
  end
end
