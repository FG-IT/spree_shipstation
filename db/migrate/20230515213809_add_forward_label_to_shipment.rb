class AddForwardLabelToShipment < ActiveRecord::Migration[7.0]
  def change
    add_column :spree_shipments, :forward, :boolean
  end
end
