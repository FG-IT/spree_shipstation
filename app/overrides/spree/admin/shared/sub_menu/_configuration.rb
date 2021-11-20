Deface::Override.new(
  virtual_path: 'spree/admin/shared/sub_menu/_configuration',
  name: 'add shipstaion to configuration tab',
  insert_bottom: '[data-hook="admin_configurations_sidebar_menu"]',
  text: '<%= configurations_sidebar_menu_item(Spree.t(:shipstation), spree.admin_shipstation_accounts_path) if can? :manage, Spree::ShipstationAccount %>'
)