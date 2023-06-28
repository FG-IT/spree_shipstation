# frozen_string_literal: true

Spree::Core::Engine.add_routes do
  post "/shipstation/:store_id", to: "shipstation#shipnotify"

  namespace :admin, path: Spree.admin_path do
    resources :shipstation_accounts
  end
end
