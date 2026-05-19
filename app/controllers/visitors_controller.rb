class VisitorsController < ApplicationController
  before_action :set_visitor

  def show
    @prediction      = @visitor.latest_prediction(kind: "persona")
    @big5_prediction = @visitor.latest_prediction(kind: "big5")
    @features        = @visitor.visitor_feature&.features || {}
    @models          = ModelConfig.active.order(:kind, :name)
  end

  def reclassify
    config =
      if params[:model_config_id].present?
        ModelConfig.find(params[:model_config_id])
      else
        @visitor.site.effective_model_config
      end

    begin
      PersonalityClassifier.call(@visitor, model_config: config)
      flash[:notice] = "Reclassified with #{config&.name || "default"}."
    rescue Llm::Error => e
      flash[:alert] = "LLM error: #{e.message}"
    end
    redirect_to site_visitor_path(@visitor.site, @visitor)
  end

  private

  def set_visitor
    @visitor = Current.user.sites
                      .find_by!(public_key: params[:site_id])
                      .visitors
                      .includes(:predictions, :visitor_feature)
                      .find(params[:id])
  end
end
