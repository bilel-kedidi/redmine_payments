class PaymentsController < ApplicationController
  unloadable
  include StripePayment

  def verify_authenticity_token

  end

  def  create_order
    if request.options?
      render partial: 'index.html.erb'
    else
      card        = get_card_info(params)
      order = Order.new
      order_items = params[:order_items]
      unless order_items.is_a?(Array)
        order_items = order_items.to_s.scan(/([a-z0-9-]+)/).flatten
      end
      if order_items.present? and order_items.is_a?(Array)
        product  = Product.where(product_uuid: order_items.first).first
        order.project_id = product.project_id if product
      end
      if order.project_id.nil?
        render json: {error: 'product not found, check admin'} && return
      end
      order       = create_customer_order(order, card, params['chargeDescription'],  params[:email])

      currency    = params[:currency].presence || 'usd'
      unless Product::CURRENCIES.include?(currency)
        currency = 'usd'
      end
      order.redirect_url = params[:redirect_url]

      unless order.status.present?
        if params[:action_payment] == 'authorize'
          # amount = params[:amount].to_f
          order.get_amount(currency)
          result = charge_customer(order, amount, currency)
          if result['paid']
            order.status = 'paid'
          else
            order.status = 'declined'
          end
        else # capture
          order.status = 'capture'
        end
      end

      order.currency = currency
      order.save

      if order_items.present? and order_items.is_a?(Array)
        order_items.each do |item|
          product  = Product.where(product_uuid: item).first
          order.add_item(product.id) if product
        end
      end
      attrs = order.attributes
      render json: attrs
    end
  end

  def add_item
    if request.options?
      render partial: 'index.html.erb'
    else
      order_id    = params['orderUUID']
      order = Order.where(order_uuid: order_id).first
      product  = Product.where(product_uuid: params['productUUID']).first
      result = nil
      result      = order.add_item(product.id) if product
      json        = {saved: result ? 'ok' : 'fail' }
      order_items = order.products.map(&:id)
      json.merge!('redirect_url'=> order.redirect_url)
      json.merge!('order_items'=> order_items)
      render json: json
    end
  rescue ActiveRecord::RecordNotFound
    render json: {record_not_foud: true}
  end

  def charge_order
    if request.options?
      render partial: 'index.html.erb'
    else
      order = Order.where(order_uuid: params['orderUUID']).first
      if params['productUUID']
        product  = Product.where(product_uuid: params['productUUID']).first
        order.add_item(product.id)
      end
      if order.products.blank?
        render json: {status: 'declined', error: 'no products'} and return
      end

      currency = order.currency
      price = order.get_amount(currency)
      result = charge_customer(order, price , currency)
      json= {redirect_url: params[:redirect_url]}
      if result['paid']
        json.merge!(status: 'paid')
      else
        json.merge!(status: 'declined')
      end
      render json: json
    end
  rescue ActiveRecord::RecordNotFound
    render json: {record_not_foud: true}
  end

  def add_lead
    if request.options?
      render partial: 'index.html.erb'
    else
      lead = params[:lead]
      redirection = lead[:redirect_to]
      redmine_lead = RedmineLead.new
      redmine_lead.safe_attributes = lead.permit!
      json = redmine_lead.save ? {saved: true} : {saved: false}
      json.merge!(:redirect_to=> redirection)
      render json: json
    end
  end

  private

  def get_card_info(params)
    {
        number: params[:cc],
        exp_month: params['month'],
        exp_year: params['year'],
        cvc: params['cvc'],
        name: params['fullName'],
        address_city: params['billing_city'],
        address_country: params['billing_country'],
        address_line1: params['billing_line1'],
        address_line2: params['billing_line2'],
        address_state: params['billing_state'],
        address_zip: params['billing_zip']
    }
  end

end
