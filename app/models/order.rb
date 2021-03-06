class Order < ActiveRecord::Base
  unloadable
  
  has_many :items
  has_many :products, through: :items

  belongs_to :project

  include Redmine::SafeAttributes
  
  safe_attributes 'charge_id_stripe',
                  'status',
                  'customer_uuid',
                  'redirect_url',
                  'currency',
                  'project_id'

  before_create :create_uuid

  def add_item(product_id)
    item = Item.new
    item.order_id = self.id
    item.product_id= product_id
    item.save
  end

  def total_price
    if currency and products.present?
      products.map{|product| product.price(currency)}.sum
    else
      0
    end
  end

  def create_uuid
    value = get_value
    # while Order.where(order_uuid: value ).present?
    #   value = get_value
    # end
    self.order_uuid = value
  end

  def get_amount(currency)
    products.map{|product|
      p = product.price_currencies.where(currency: currency).first || PriceCurrency.new(currency: currency)
      p.price.to_f
    }.compact.sum
  end


  def get_value
    UUID.new.generate
    # o = [('a'..'z')].map { |i| i.to_a * 2 }.flatten.shuffle.first(2).join
    # nume = [(0..9)].map { |i| i.to_a * 4 }.flatten.shuffle.first(4).join
    # "#{o}#{nume}"
  end

end
