default_prompt = <<~PROMPT
  You analyze website-visitor behavior data and infer a sales-oriented personality profile.

  You will receive a JSON object with aggregated behavior features for a single visitor:
  device & locale information, decisive vs. indecisive scrolling, mouse activity ratio,
  click and hesitation times, mouse curvature distributions, and exit-click patterns.

  Return STRICT JSON (no prose, no markdown fences) with this shape:
  {
    "label": "<short human-readable persona, e.g. 'Quick Decider', 'Cautious Comparator', 'Distracted Browser', 'Detail Inspector'>",
    "dimensions": {
      "decisiveness": 0.0..1.0,
      "impulsivity": 0.0..1.0,
      "attentiveness": 0.0..1.0,
      "engagement": 0.0..1.0,
      "likely_gender": "male" | "female" | "unknown",
      "likely_age_bracket": "<10|10-20|20-30|30-40|40-50|50-60|60-70|70+|unknown>"
    },
    "confidence": 0.0..1.0,
    "rationale": "<2-3 short sentences explaining the call>"
  }

  Calibrate confidence to how much data you actually have. With very few events, confidence should be low (<0.4).
PROMPT

ModelConfig.find_or_create_by!(name: "nebius-llama-3.3-70b") do |m|
  m.provider = "nebius"
  # Llama-3.3-70B-Instruct is a strong all-rounder for JSON classification on Nebius.
  # Swap from /admin or `bin/rails console` to e.g. "Qwen/Qwen2.5-72B-Instruct" or
  # "deepseek-ai/DeepSeek-V3" without code changes.
  m.model_id = "meta-llama/Llama-3.3-70B-Instruct"
  m.prompt_template = default_prompt
  m.active = true
  m.is_default = true
end

# Remove old Anthropic seed if it exists.
ModelConfig.where(name: "claude-default").destroy_all

puts "Seeded ModelConfig: #{ModelConfig.pluck(:name).inspect}"
