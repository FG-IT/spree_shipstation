module Spree
  class OrderAddressVerification < ApplicationRecord
    belongs_to :order
  end
end