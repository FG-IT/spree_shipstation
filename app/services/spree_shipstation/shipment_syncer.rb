module SpreeShipstation
  class ShipmentSyncer
    PAGE_SIZE = 50
    def initialize(shipstation_account)
      @shipstation_account = shipstation_account
      @api_key = shipstation_account.api_key
      @api_secret = shipstation_account.api_secret
      @api_client = SpreeShipstation::Api.new(@api_key, @api_secret)
      @last_create_on = ((@shipstation_account.shipments_sync_until || Spree::Order.minimum(:created_at)) - 2.days).to_formatted_s(:iso8601)
      @page = 1
    end

    def sync
      if @api_key.present? && @api_secret.present?
        params = generate_params
        res = @api_client.get_shipments(params)
        @last_create_on = process_response(res)
        if @last_create_on.present?
          @shipstation_account.update(shipments_sync_until: @last_create_on)
          wait
          sync
        end
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
      {
        'page' => @page,
        'pageSize' => PAGE_SIZE,
        'sortBy' => 'createDate',
        'createDateStart' => @last_create_on,
        'createDateEnd' => DateTime.tomorrow.end_of_day.to_formatted_s(:iso8601)
      }
    end

    def process_response(res)
      res['shipments']&.each do |ss_shipment|
        spree_shipment_id = ss_shipment['orderNumber']
        spree_shipment = Spree::Shipment.find_by(number: spree_shipment_id)
        spree_shipment&.update_column(:actual_cost, ss_shipment['shipmentCost'])
      end
      res['shipments']&.size == PAGE_SIZE ? res['shipments']&.last&.try(:[], 'createDate') : nil
    end
    
  end
end