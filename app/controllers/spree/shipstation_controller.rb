# frozen_string_literal: true

module Spree
  class ShipstationController < Spree::BaseController
    protect_from_forgery with: :null_session, only: :shipnotify

    before_action :authenticate_shipstation

    def export
      store_id = params[:store_id]
      @shipments = ::Spree::Shipment.joins(:shipstation_order).where(shipstation_order: {needed: true, shipstation_account_id: store_id})
        .includes([{order: {ship_address: [:state, :country], bill_address: [:state, :country]}, selected_shipping_rate: :shipping_method}, :inventory_units])
        .between(date_param(:start_date), date_param(:end_date))
        .page(params[:page])
        .per(50)

      shipment_ids = @shipments.map {|shipment| shipment.id }
      line_item_ids = ::Spree::InventoryUnit.where(shipment_id: shipment_ids).map {|inventory_unit| inventory_unit.line_item_id }
      @line_items = ::Hash[ ::Spree::LineItem.includes([{variant: [{option_values: :option_type}, :product, :images]}, :refund_items]).where(id: line_item_ids).map do |line_item|
        [line_item.id, line_item] 
      end ]

      respond_to do |format|
        format.xml { render layout: false }
      end
    end

    def shipnotify
      SpreeShipstation::ShipmentNotice.from_payload(params.to_unsafe_h, request.raw_post).apply
      head :ok
    rescue SpreeShipstation::Error
      head :bad_request
    end

    private

    def date_param(name)
      return if params[name].blank?

      Time.strptime("#{params[name]} UTC", "%m/%d/%Y %H:%M %Z")
    end

    def authenticate_shipstation
      authenticate_or_request_with_http_basic do |username, password|
        @shipstation_account = Spree::ShipstationAccount.find_by(username: username)
        @shipstation_account.present? && password == @shipstation_account.password
      end
    end
  end
end
