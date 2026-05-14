class VisitorsController < ApplicationController
  def show
    @visitor = Current.user.sites
                      .find_by!(public_key: params[:site_id])
                      .visitors
                      .includes(:predictions, :visitor_feature)
                      .find(params[:id])
    @prediction = @visitor.latest_prediction
    @features   = @visitor.visitor_feature&.features || {}
  end
end
