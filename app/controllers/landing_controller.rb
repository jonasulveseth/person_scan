class LandingController < ApplicationController
  allow_unauthenticated_access only: %i[splash how_it_works pricing]
  layout "landing"

  def splash
    redirect_to sites_path and return if authenticated?
  end

  def how_it_works
    redirect_to sites_path and return if authenticated?
  end

  def pricing
  end
end
