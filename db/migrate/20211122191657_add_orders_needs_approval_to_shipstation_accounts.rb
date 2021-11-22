class AddOrdersNeedsApprovalToShipstationAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipstation_accounts, :orders_need_approval, :boolean, default: true
  end
end
