class TrainingExamplesController < ApplicationController
  before_action :set_example, only: %i[show destroy edit update]

  def index
    @examples = TrainingExample.order(created_at: :desc)
    @by_source = TrainingExample.group(:source).count
    @by_gender = TrainingExample.group("ground_truth->>'gender'").count
    @by_age    = TrainingExample.group("ground_truth->>'age_bracket'").count
  end

  def show; end

  def new
    @example = TrainingExample.new(source: "manual", ground_truth: {}, features: {})
  end

  def create
    @example = TrainingExample.new(create_params)
    @example.source = "manual" if @example.source.blank?
    if @example.save
      redirect_to training_examples_path, notice: "Training example added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @example.update(update_params)
      redirect_to training_examples_path, notice: "Updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @example.destroy
    redirect_to training_examples_path, notice: "Removed."
  end

  # POST /training_examples/import_legacy
  def import_legacy
    path = params[:path].presence || File.expand_path("~/Sites/individlabs_person_scan/db/development.sqlite3")
    unless File.exist?(path)
      redirect_to training_examples_path, alert: "Legacy SQLite not found at #{path}"
      return
    end
    result = LegacyImporter.call(path)
    redirect_to training_examples_path,
                notice: "SQLite import: #{result.imported} new, #{result.updated} updated, #{result.skipped} skipped. Errors: #{result.errors.size}"
  end

  # POST /training_examples/import_csv
  def import_csv
    path = params[:path].presence || File.expand_path("~/Sites/individlabs_person_scan/public/csv/gender.csv")
    unless File.exist?(path)
      redirect_to training_examples_path, alert: "CSV not found at #{path}"
      return
    end
    result = LegacyCsvImporter.call(path)
    redirect_to training_examples_path,
                notice: "CSV import: #{result.imported} new, #{result.updated} updated, #{result.skipped} skipped. Errors: #{result.errors.size}"
  end

  # POST /sites/:site_id/visitors/:id/save_as_training_example
  def save_from_visitor
    site = Current.user.sites.find_by!(public_key: params[:site_id])
    visitor = site.visitors.find(params[:id])

    feature = visitor.visitor_feature || FeatureAggregator.call(visitor)
    gt = { "gender" => params[:gender], "age_bracket" => params[:age_bracket] }.compact_blank

    TrainingExample.create!(
      visitor: visitor,
      source: "visitor_label",
      features: feature.features,
      ground_truth: gt,
      notes: params[:notes]
    )
    redirect_to site_visitor_path(site, visitor), notice: "Saved as training example."
  end

  private

  def set_example
    @example = TrainingExample.find(params[:id])
  end

  def create_params
    base = params.expect(training_example: %i[source notes features_json gender age_bracket])
    {
      source: base["source"],
      notes:  base["notes"],
      features: parse_json(base["features_json"]),
      ground_truth: { "gender" => base["gender"], "age_bracket" => base["age_bracket"] }.compact_blank
    }
  end

  def update_params
    base = params.expect(training_example: %i[source notes features_json gender age_bracket])
    {
      source: base["source"],
      notes:  base["notes"],
      features: parse_json(base["features_json"]),
      ground_truth: { "gender" => base["gender"], "age_bracket" => base["age_bracket"] }.compact_blank
    }
  end

  def parse_json(s)
    return {} if s.blank?
    JSON.parse(s)
  rescue JSON::ParserError
    {}
  end
end
