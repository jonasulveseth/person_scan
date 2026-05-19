class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  layout "auth", only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to pricing_path, alert: "Try again later." }

  def new
    @plan = params[:plan].to_s
    unless User::PLANS.include?(@plan)
      redirect_to pricing_path, notice: "Choose a plan to get started." and return
    end
    @user = User.new
  end

  def create
    @plan = (params.dig(:user, :plan) || params[:plan]).to_s
    unless User::PLANS.include?(@plan)
      redirect_to pricing_path, alert: "Please choose a plan to continue." and return
    end

    @user = User.new(user_params)
    @user.plan = @plan
    if @user.save
      start_new_session_for(@user)
      if @user.plan == "free"
        redirect_to sites_path, notice: "Welcome!"
      else
        redirect_to new_stripe_checkout_path(plan: @user.plan)
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: %i[email_address password password_confirmation])
  end
end
