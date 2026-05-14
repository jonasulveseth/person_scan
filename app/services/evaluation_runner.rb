class EvaluationRunner
  def self.call(model_config:, limit: 50, sampling: :random)
    new(model_config: model_config, limit: limit, sampling: sampling).call
  end

  def initialize(model_config:, limit:, sampling:)
    @model_config = model_config
    @limit = limit
    @sampling = sampling
  end

  def call
    run = EvaluationRun.create!(
      model_config: @model_config,
      started_at: Time.current,
      total: 0,
      correct_gender: 0,
      correct_age_bracket: 0,
      avg_confidence: 0,
      results: []
    )

    examples = pick_examples
    provider = Llm::Provider.for(@model_config)
    results = []
    correct_gender = 0
    correct_age = 0
    conf_sum = 0.0
    age_evaluated = 0

    examples.each do |ex|
      begin
        result = provider.classify(ex.features.to_json)
        pg = result.dimensions["likely_gender"].to_s.downcase
        pa = result.dimensions["likely_age_bracket"].to_s

        gender_ok = (pg == ex.truth_gender.to_s.downcase)
        age_ok    = ex.truth_age_bracket.present? && (pa == ex.truth_age_bracket.to_s)

        correct_gender += 1 if gender_ok
        if ex.truth_age_bracket.present?
          age_evaluated += 1
          correct_age += 1 if age_ok
        end
        conf_sum += result.confidence.to_f

        results << {
          training_example_id: ex.id,
          truth: ex.ground_truth,
          predicted: {
            gender: pg, age_bracket: pa, label: result.label, confidence: result.confidence
          },
          gender_ok: gender_ok,
          age_ok: age_ok
        }
      rescue Llm::Error => e
        results << { training_example_id: ex.id, error: "#{e.class}: #{e.message}" }
      end
    end

    n = examples.size
    run.update!(
      finished_at: Time.current,
      total: n,
      correct_gender: correct_gender,
      correct_age_bracket: correct_age,
      avg_confidence: (n.zero? ? 0 : (conf_sum / n).round(4)),
      results: { examples: results, age_evaluated: age_evaluated }
    )
    run
  end

  private

  def pick_examples
    scope = TrainingExample.for_eval
    case @sampling
    when :first then scope.order(:id).limit(@limit)
    else             scope.order("RANDOM()").limit(@limit)
    end
  end
end
