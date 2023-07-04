module SpreeShipstation
  class Api
    END_POINT = 'https://ssapi.shipstation.com'

    attr_reader :api_key, :api_secret, :x_rate_limit_limit, 
                :x_rate_limit_remaining, :x_rate_limit_reset
    def initialize(api_key, api_secret)
      @api_key = api_key
      @api_secret = api_secret
    end

    def list_shipments(params)
      path = 'shipments'
      make_request('Get', path, params)
    end

    def create_orders(params)
      path = 'orders/createorders'
      post_action(path, params)
    end

    def list_orders(params)
      path = 'orders'
      make_request('Get', path, params)
    end

    def update_orders(params)
      path = 'orders/createorders'
      post_action(path, params)
    end

    def delete_order(order_id)
      path = "orders/#{order_id}"
      make_request('Delete', path, {})
    end

    def create_order(params)
      path = 'orders/createorder'
      post_action(path, params)
    end

    def post_action(path, params)
      url = URI("#{END_POINT}/#{path}")
      json_payload = JSON.generate(params)

      request = get_request('Post', url)
      add_auth(request)

      https = get_https(url)

      request['Content-Type'] = 'application/json'
      request.body = json_payload

      resp = nil
      while true do
        response = https.request(request)
        set_rate_limit_info(response.header)

        if response.code.to_i >= 200 && response.code.to_i < 300
          resp = JSON.parse(response.read_body)
          break
        else
          Rails.logger.debug("[ShipstationApiError] Code: #{response.code}, Body: #{response.read_body}")
          sleep response.header['X-Rate-Limit-Reset'].to_i + 1
        end
      end

      resp
    end

    def make_request(method, path, params)
      if method == 'Get'
        url = URI("#{END_POINT}/#{path}?#{params.map{|k, v| "#{k}=#{v}"}.join('&')}")
      else
        url = URI("#{END_POINT}/#{path}")
      end

      request = get_request(method, url)
      add_auth(request)
      https = get_https(url)

      request['Content-Type'] = 'application/json'

      if method != 'Get' && params.present?
        json_payload = JSON.generate(params)
        request.body = json_payload
      end

      resp = nil
      while true do
        response = https.request(request)
        set_rate_limit_info(response.header)

        if response.code.to_i >= 200 && response.code.to_i < 300
          resp = JSON.parse(response.read_body)
          break
        else
          if response.code.to_i == 429
            sleep response.header['X-Rate-Limit-Reset'].to_i + 1
          end
        end
      end

      resp
    end

    private 
    def set_rate_limit_info(headers)
      @x_rate_limit_limit = headers['X-Rate-Limit-Limit'].to_i
      @x_rate_limit_remaining = headers['X-Rate-Limit-Remaining'].to_i
      @x_rate_limit_reset = headers['X-Rate-Limit-Reset'].to_i
    end

    def get_request(method, url)
      "::Net::HTTP::#{method}".constantize.new(url)
    end

    def get_https(url)
      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true
      https
    end

    def add_auth(request)
      credentials = "#{@api_key}:#{@api_secret}"
      encoded_credentials = Base64.strict_encode64(credentials)
      request["Authorization"] = "Basic #{encoded_credentials}"
    end
  end
end
