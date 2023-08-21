module SpreeShipstation
  class ShipmentSyncer
    PAGE_SIZE = 500
    STATE_MAP = {
      pending: :awaiting_payment,
      ready: :awaiting_shipment,
      shipped: :shipped,
      canceled: :cancelled
    }

    DATE_FORMAT = '%Y-%m-%d'

    def initialize(shipstation_account)
      @shipstation_account = shipstation_account
      @api_key = shipstation_account.api_key
      @api_secret = shipstation_account.api_secret
      @api_client = SpreeShipstation::Api.new(@api_key, @api_secret)
      @last_create_on = ((@shipstation_account.shipments_sync_until || Spree::Order.minimum(:created_at)) - 2.days).to_formatted_s(:iso8601)
      @page = 1
    end

    def sync_shipments(days=7, params={})
      return unless @api_key.present? && @api_secret.present?

      dft_params = {
        page: 1,
        pageSize: PAGE_SIZE,
        shipDateStart: days.days.ago.strftime('%Y-%m-%d'),
        sortBy: 'ShipDate',
      }

      filter = {}
      filter.merge!(dft_params, params)
      filter[:storeId] = @shipstation_account.shipstation_store_id if @shipstation_account.shipstation_store_id.present?

      while true do
        res = @api_client.list_shipments(filter)
        break if res.blank? || res['shipments'].blank?

        shipment_numbers = res['shipments'].map {|ss| ss['orderNumber'] }
        shipments_mapping = ::Hash[ ::Spree::Shipment.where(number: shipment_numbers).map {|shipment| [shipment.number, shipment] } ]
        res['shipments'].each do |ss|
          shipment = shipments_mapping.fetch(ss['orderNumber'], nil)
          if shipment.blank? || (shipment.tracking.present? && shipment.carrier.present? && shipment.actual_cost > 0)
            Rails.logger.info("[ShipmentCostAlreadyExist] #{shipment&.number}")
            next
          end
          Rails.logger.info("[ShipmentSync] Shipstation: #{ss}, Website: #{shipment.to_json}")

          attrs = { actual_cost: ss['shipmentCost'] }
          attrs[:carrier] = get_carrier(ss['carrierCode'], ss['serviceCode']) if shipment.carrier.blank?
          attrs[:tracking] = ss['trackingNumber'] if shipment.tracking.blank?
          begin
            shipment&.update_attributes_and_order(attrs)
            Rails.logger.info("[ShipmentSynced] Shipment: #{shipment.number}, Info: #{attrs}")
          rescue
            Rails.logger.warn("[ShipmentUpdateTrackingFailed] Number: #{ss['orderNumber']}, Attrs: #{attrs}")
          end
        end

        pages = res.fetch('pages', 1)
        break if filter[:page] >= pages

        filter[:page] += 1
      end
    end

    def sync_shipment_orders(params={})
      dft_params = {
        page: 1,
        pageSize: PAGE_SIZE,
        createDateStart: 7.days.ago.strftime('%Y-%m-%d'),
        sortBy: 'CreateDate',
      }

      filter = {}
      filter.merge!(dft_params, params)
      filter[:storeId] = @shipstation_account.shipstation_store_id if @shipstation_account.shipstation_store_id.present?

      while true do
        res = list_shipstation_orders(filter)
        break if res.blank? || res['orders'].blank?

        res_orders = ::Hash[ res['orders'].map {|r| [r['orderNumber'], r] } ]
        shipment_numbers = res['orders'].map {|r| r['orderNumber'] }
        shipments = ::Spree::Shipment.where(number: shipment_numbers)
        shipments_mapping = ::Hash[ shipments.map {|shipment| [shipment.id, {shipment: shipment, shipstation: res_orders.fetch(shipment['number'], nil)}] } ]
        
        shipment_ids = shipments.map {|shipment| shipment.id }
        ::Spree::ShipstationOrder.where(shipment_id: shipments_mapping.keys).each do |shipstation_order|
          sm = shipments_mapping.delete(shipstation_order.shipment_id)
          next if sm[:shipstation].blank?

          shipstation_order.update(order_id: sm[:shipstation]['orderId'], order_key: sm[:shipstation]['orderKey'])
        end

        return if shipments_mapping.blank?

        shipstation_orders_arr = shipments_mapping.values.map do |sm|
          next if sm[:shipstation].blank?
          {
            shipment_id: sm[:shipment].id,
            order_id: sm[:shipstation]['orderId'],
            order_key: sm[:shipstation]['orderKey'],
            needed: true,
            created_at: sm[:shipstation]['createDate'],
            updated_at: sm[:shipstation]['modifyDate']
          }
        end.compact
        ::Spree::ShipstationOrder.insert_all(shipstation_orders_arr)

        pages = res.fetch('pages', 1)
        break if filter[:page] >= pages

        filter[:page] += 1
      end
    end

    def process_shipstation_orders(shipstation_orders)
      sos = []
      shipstation_orders.each do |so|
        if so.data.present?
          data = JSON.parse(so.data, {symbolize_names: true})
          sos << data
        else
          data = so.shipstation_order_data
          so.data = JSON.generate(data)
          so.is_update = false
          so.save

          sos << data
        end
      end

      res = create_shipstation_orders(sos)
      unless res
        Rails.logger.debug("[ShipstationPayload] #{params}")
      end
      Rails.logger.debug("[ShipstationResponse] #{res}")

      return unless res.present? && res['results'].present?

      shipments = ::Hash[ ::Spree::Shipment.where(id: shipstation_orders.map {|so| so.shipment_id }.uniq).map {|shipment| [shipment.id, shipment] } ]
      shipstation_orders_h = ::Hash[ shipstation_orders.map {|so| [shipments[so.shipment_id].try(:number), so] } ]
      res['results'].each do |resp|
        next if resp.blank?

        next unless resp.fetch('success', false)

        shipstation_order = shipstation_orders_h.fetch(resp['orderNumber'], nil)
        next if shipstation_order.blank?

        if shipstation_order.order_id != resp['orderId'] || shipstation_order.order_key != resp['orderKey']
          shipstation_order.update(order_id: resp['orderId'], order_key: resp['orderKey'])
        end
      end
    end

    def create_shipstation_orders(params)
      @api_client.create_orders(params)
    end

    def update_shipstation_orders(params)
      @api_client.update_orders(params)
    end

    def list_shipstation_orders(params)
      @api_client.list_orders(params)
    end

    def list_shipstation_shipments(params)
      @api_client.list_shipments(params)
    end

    def delete_shipstation_order(order_id)
      @api_client.delete_order(order_id)
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
