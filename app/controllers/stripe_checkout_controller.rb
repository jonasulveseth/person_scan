class StripeCheckoutController < ApplicationController
  PLANS = {
    "starter" => { name: "Starter", price: "€29", profiles: 1_000 },
    "growth"  => { name: "Growth",  price: "€99", profiles: 10_000 },
    "scale"   => { name: "Scale",   price: "€299", profiles: 50_000 }
  }.freeze

  def new
    plan = params[:plan].to_s
    unless PLANS.key?(plan)
      redirect_to pricing_path, alert: "Unknown plan." and return
    end

    unless StripeConfig.configured?
      redirect_to pricing_path, alert: "Payments aren't configured yet — talk to us." and return
    end

    price_id = StripeConfig.price_id(plan)
    if price_id.blank? || price_id.start_with?("REPLACE_")
      redirect_to pricing_path, alert: "The #{PLANS[plan][:name]} plan isn't set up in Stripe yet." and return
    end

    Stripe.api_key = StripeConfig.secret_key
    user = Current.user

    if user.stripe_customer_id.blank?
      customer = Stripe::Customer.create(
        email: user.email_address,
        metadata: { user_id: user.id }
      )
      user.update_column(:stripe_customer_id, customer.id)
    end

    session = Stripe::Checkout::Session.create(
      customer: user.stripe_customer_id,
      mode: "subscription",
      line_items: [{ price: price_id, quantity: 1 }],
      success_url: success_stripe_checkout_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url:  cancel_stripe_checkout_url,
      metadata: { user_id: user.id, plan: plan },
      subscription_data: { trial_period_days: 14, metadata: { user_id: user.id, plan: plan } }
    )

    user.update!(plan: plan) if user.plan != plan
    redirect_to session.url, allow_other_host: true
  end

  def success
    if params[:session_id].present?
      Stripe.api_key = StripeConfig.secret_key
      begin
        cs = Stripe::Checkout::Session.retrieve(params[:session_id])
        if %w[paid no_payment_required].include?(cs.payment_status) && cs.subscription.present?
          stripe_sub = Stripe::Subscription.retrieve(cs.subscription)
          Subscription.find_or_create_by!(stripe_subscription_id: stripe_sub.id) do |s|
            s.user = Current.user
            s.stripe_price_id = stripe_sub.items.data.first&.price&.id
            s.plan = Current.user.plan
            s.status = stripe_sub.status
            s.trial_ends_at = stripe_sub.trial_end ? Time.at(stripe_sub.trial_end) : nil
            s.current_period_end = stripe_sub.current_period_end ? Time.at(stripe_sub.current_period_end) : nil
          end
        end
      rescue Stripe::StripeError => e
        Rails.logger.error "[Stripe] success verify failed: #{e.message}"
      end
    end
    redirect_to sites_path, notice: "Welcome! Your 14-day free trial has started."
  end

  def cancel
    redirect_to pricing_path, notice: "Checkout cancelled. You can try again anytime."
  end
end
