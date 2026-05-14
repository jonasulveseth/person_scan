class EvaluationRunsController < ApplicationController
  before_action :set_run, only: :show

  def index
    @runs = EvaluationRun.includes(:model_config).order(started_at: :desc)
    @models = ModelConfig.active.order(:name)
  end

  def show; end

  def create
    config = ModelConfig.find(params[:model_config_id])
    limit  = (params[:limit].presence || 20).to_i.clamp(1, 500)
    run = EvaluationRunner.call(model_config: config, limit: limit)
    redirect_to evaluation_run_path(run), notice: "Eval complete: #{run.total} examples"
  rescue => e
    redirect_to evaluation_runs_path, alert: "Eval failed: #{e.message}"
  end

  private

  def set_run
    @run = EvaluationRun.includes(:model_config).find(params[:id])
  end
end
