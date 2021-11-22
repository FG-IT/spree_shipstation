# frozen_string_literal: true

module Spree
  class ShipstationController < Spree::BaseController
    protect_from_forgery with: :null_session, only: :shipnotify

    before_action :authenticate_shipstation

    def export
      @shipments = Spree::Shipment.includes({order: [:ship_address, :bill_address]})
        .where(stock_location_id: @shipstation_account.stock_location_ids)
        .exportable(@shipstation_account.orders_need_approval)
        .between(date_param(:start_date), date_param(:end_date))
        .page(params[:page])
        .per(50)

      respond_to do |format|
        format.xml { render layout: false }
      end
    end

    def shipnotify
      SpreeShipstation::ShipmentNotice.from_payload(params.to_unsafe_h).apply
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
