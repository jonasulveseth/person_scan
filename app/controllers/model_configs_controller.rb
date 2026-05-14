class ModelConfigsController < ApplicationController
  before_action :set_model_config, only: %i[show edit update destroy make_default]

  def index
    @model_configs = ModelConfig.order(:provider, :name)
    @provider_status = Llm::Provider.provider_options.to_h
  end

  def show
    @prediction_count = @model_config.predictions.count
  end

  def new
    @model_config = ModelConfig.new(active: true)
    @provider_options = provider_options
  end

  def create
    @model_config = ModelConfig.new(model_config_params)
    if @model_config.save
      redirect_to model_configs_path, notice: "Model added."
    else
      @provider_options = provider_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @provider_options = provider_options
  end

  def update
    if @model_config.update(model_config_params)
      redirect_to model_configs_path, notice: "Model updated."
    else
      @provider_options = provider_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @model_config.predictions.exists?
      redirect_to model_configs_path, alert: "Can't delete a model with existing predictions; deactivate it instead."
    else
      @model_config.destroy
      redirect_to model_configs_path, notice: "Model removed."
    end
  end

  def make_default
    @model_config.update!(is_default: true, active: true)
    redirect_to model_configs_path, notice: "#{@model_config.name} is now the default."
  end

  private

  def set_model_config
    @model_config = ModelConfig.find(params[:id])
  end

  def provider_options
    Llm::Provider.provider_options.map { |p, has_key| [p, has_key ? "✓ key configured" : "no key in credentials"] }
  end

  def model_config_params
    params.expect(model_config: %i[name provider model_id prompt_template active is_default])
  end
end
