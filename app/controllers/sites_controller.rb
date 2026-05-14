class SitesController < ApplicationController
  before_action :set_site, only: %i[show edit update destroy trends]

  def index
    @sites = Current.user.sites.order(created_at: :desc)
  end

  def new
    @site = Current.user.sites.build
  end

  def create
    @site = Current.user.sites.build(site_params)
    if @site.save
      redirect_to @site, notice: "Site created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @visitors = @site.visitors.includes(:predictions).order(last_seen_at: :desc).limit(50)
    @snippet = view_context.content_tag(:script, "", src: "#{request.base_url}/t.js?site=#{@site.public_key}")
  end

  def trends
    @trends = SiteTrends.call(@site)
  end

  def edit; end

  def update
    if @site.update(site_params)
      redirect_to @site, notice: "Updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @site.destroy
    redirect_to sites_path, notice: "Site deleted."
  end

  private

  def set_site
    @site = Current.user.sites.find_by!(public_key: params[:id])
  end

  def site_params
    params.expect(site: %i[name url active model_config_id])
  end
end
