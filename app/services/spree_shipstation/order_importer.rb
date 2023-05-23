module SpreeShipstation
  class OrderImporter
    def initialize(shipstation_account)
      @shipstation_account = shipstation_account
      @api_key = shipstation_account.api_key
      @api_secret = shipstation_account.api_secret
      @api_client = SpreeShipstation::Api.new(@api_key, @api_secret)
    end

    def import_order(shipment)
      return if @api_key.blank? || @api_secret.blank?

      params = generate_params
      res = @api_client.get_shipments(params)
      @last_create_on = process_response(res)
      if @last_create_on.present?
        @shipstation_account.update(shipments_sync_until: @last_create_on)
        wait
        sync
      end
    end

    def wait
      if @api_client.x_rate_limit_remaining.try(:<, 5)
        sleep @api_client.x_rate_limit_reset + 1
      else
        sleep 3
      end
    end

    def generate_params
      p = {
        'page' => @page,
        'pageSize' => PAGE_SIZE,
        'sortBy' => 'createDate',
        'createDateStart' => @last_create_on,
        'createDateEnd' => DateTime.tomorrow.end_of_day.to_formatted_s(:iso8601)
      }
      p['storeId'] = @shipstation_account.shipstation_store_id if @shipstation_account.shipstation_store_id.present?
      p
    end

    def process_response(res)
      res['shipments']&.each do |ss_shipment|
        spree_shipment = Spree::Shipment.find_by(number: ss_shipment['orderNumber'])
        next if spree_shipment.blank?
        attrs = { actual_cost: ss_shipment['shipmentCost'] }
        attrs[:carrier] = get_carrier(ss_shipment['carrierCode'], ss_shipment['serviceCode']) if spree_shipment.carrier.blank?
        attrs[:tracking] = ss_shipment['trackingNumber'] if spree_shipment.tracking.blank?
        spree_shipment&.update_columns(attrs)
      end
      res['shipments']&.size == PAGE_SIZE ? res['shipments']&.last&.try(:[], 'createDate') : nil
    end
    
    def get_carrier(carrier_code, service_code)
      if carrier_code == 'stamps_com' && service_code.start_with?('usps_')
        'USPS'
      else
        carrier_code.upcase
      end
    end
  end
end