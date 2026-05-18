class StripeWebhooksController < ActionController::API
  def create
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    secret = StripeConfig.webhook_secret

    if secret.blank? || secret.start_with?("REPLACE_")
      head :service_unavailable and return
    end

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, secret)
    rescue JSON::ParserError, Stripe::SignatureVerificationError => e
      Rails.logger.warn "[Stripe webhook] rejected: #{e.message}"
      head :bad_request and return
    end

    case event.type
    when "customer.subscription.created", "customer.subscription.updated"
      sync_subscription(event.data.object)
    when "customer.subscription.deleted"
      mark_subscription_cancelled(event.data.object)
    end

    head :ok
  end

  private

  def sync_subscription(stripe_sub)
    user_id = stripe_sub.metadata["user_id"] || User.find_by(stripe_customer_id: stripe_sub.customer)&.id
    return unless user_id

    sub = Subscription.find_or_initialize_by(stripe_subscription_id: stripe_sub.id)
    sub.user_id            = user_id
    sub.stripe_price_id    = stripe_sub.items.data.first&.price&.id
    sub.plan               = stripe_sub.metadata["plan"] || sub.plan || "starter"
    sub.status             = stripe_sub.status
    sub.trial_ends_at      = stripe_sub.trial_end ? Time.at(stripe_sub.trial_end) : nil
    sub.current_period_end = stripe_sub.current_period_end ? Time.at(stripe_sub.current_period_end) : nil
    sub.save!

    User.where(id: user_id).update_all(plan: sub.plan) if %w[active trialing].include?(sub.status)
  end

  def mark_subscription_cancelled(stripe_sub)
    sub = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
    return unless sub
    sub.update!(status: "canceled")
    sub.user.update!(plan: "free") if sub.user.active_subscription.blank?
  end
end
