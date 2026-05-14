class ApiKeysController < ApplicationController
  before_action :set_site
  before_action :set_key, only: %i[destroy revoke]

  def index
    @api_keys = @site.api_keys.order(created_at: :desc)
  end

  def create
    @api_key = @site.api_keys.create!(name: params[:name].presence || "API key #{Time.current.to_i}")
    redirect_to site_api_keys_path(@site), notice: "Created. Save this token now — it won't be shown again: #{@api_key.token}"
  end

  def destroy
    @api_key.destroy
    redirect_to site_api_keys_path(@site), notice: "Key deleted."
  end

  def revoke
    @api_key.update!(active: false)
    redirect_to site_api_keys_path(@site), notice: "Key revoked."
  end

  private

  def set_site
    @site = Current.user.sites.find_by!(public_key: params[:site_id])
  end

  def set_key
    @api_key = @site.api_keys.find(params[:id])
  end
end
