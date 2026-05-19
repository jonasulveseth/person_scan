default_prompt = <<~PROMPT
  You are a behavioral classifier for website visitors. You receive a JSON object with aggregated client-side
  behavior features (mouse motion, scroll style, click hesitation, device, locale) and infer a sales-oriented
  persona, plus best-guess demographic estimates.

  Return STRICT JSON only. No prose, no markdown fences, no preface. Conform exactly to this schema:

  {
    "label": "<one short human persona, max 4 words>",
    "dimensions": {
      "decisiveness":  0.0-1.0,
      "impulsivity":   0.0-1.0,
      "attentiveness": 0.0-1.0,
      "engagement":    0.0-1.0,
      "likely_gender":       one of: "male", "female",
      "likely_age_bracket":  one of EXACTLY these strings:
                             "<10", "10-20", "20-30", "30-40", "40-50",
                             "50-60", "60-70", "70+"
    },
    "confidences": {
      "decisiveness":        0.0-1.0,
      "impulsivity":         0.0-1.0,
      "attentiveness":       0.0-1.0,
      "engagement":          0.0-1.0,
      "likely_gender":       0.0-1.0,
      "likely_age_bracket":  0.0-1.0
    },
    "confidence": 0.0-1.0,
    "rationale": "<2-3 short sentences, plain prose>"
  }

  Hard rules:
  - Never return a range like "20-40" or any string not in the enum above for likely_age_bracket.
  - For likely_gender and likely_age_bracket: ALWAYS commit to a directional best-guess. Do NOT
    return "unknown" for these two fields. Use session.device_width, session.mobile_like,
    session.browser_language, session.timezone_offset, mouse_motion patterns (slow + deliberate
    skews older, fast + jittery skews younger), and click hesitation as weak demographic cues.
  - Each field has its OWN confidence in the "confidences" object. Rate each dimension on its own:
    a clear "Familiar Returner" persona may deserve 0.7 confidence, while age_bracket from the
    same data may deserve only 0.30. Do not collapse to one shared number.
      * Gender from locale + device class + motion patterns: typically 0.55-0.80.
      * Age bracket: 0.25-0.45 unless multiple strong cues align.
      * Behavioral dimensions (decisiveness/impulsivity/attentiveness/engagement): typically
        0.50-0.80 when there's plenty of behavioral data, lower when sparse.
  - The top-level "confidence" reflects the overall persona/label call (not demographics).
    Calibrate it honestly: with <10 events of behavior data, keep it at most 0.4.
  - The "label" should be useful for a salesperson: e.g. "Quick Decider", "Cautious Comparator",
    "Distracted Browser", "Detail Inspector", "Casual Returner".

  Example output (do not copy the values; this only illustrates the SHAPE):
  {"label":"Cautious Comparator","dimensions":{"decisiveness":0.45,"impulsivity":0.25,"attentiveness":0.7,"engagement":0.6,"likely_gender":"female","likely_age_bracket":"40-50"},"confidences":{"decisiveness":0.65,"impulsivity":0.55,"attentiveness":0.70,"engagement":0.65,"likely_gender":0.70,"likely_age_bracket":0.35},"confidence":0.60,"rationale":"High link-hover overtime and indecisive scrolling suggest careful comparison. Mouse activity is steady. Older-bracket device patterns are a weak signal."}


  Familiarity normalization:
  - The features object includes a "familiarity" block: is_returning,
    distinct_active_days, total_page_visits, visits_to_current_url,
    visitor_age_seconds, and time_to_first_move_ms (ms from page load
    to the first purposeful mouse movement).
  - Fast, decisive, low-hesitation behavior in a RETURNING visitor
    (is_returning=true OR distinct_active_days>1 OR visits_to_current_url>1
    OR a very SHORT time_to_first_move_ms) usually reflects site
    familiarity, not personality. Discount decisiveness/impulsivity
    signals accordingly and prefer a label like "Familiar Returner",
    "Repeat Buyer", or "Known Browser".
  - For NEW visitors (is_returning=false AND distinct_active_days<=1),
    the same fast behavior is a genuine personality signal — keep
    decisiveness/impulsivity high.
  - time_to_first_move_ms interpretation: <800ms suggests goal-directed
    visitor with a target in mind; 800-2500ms is typical orienting; >2500ms
    suggests slow/distracted/cautious orientation. Always read this in
    conjunction with is_returning before drawing personality conclusions.
PROMPT

# Default = Nebius/Llama-3.3. Idempotent across runs.
default = ModelConfig.find_or_initialize_by(name: "nebius-llama-3.3-70b")
default.assign_attributes(
  provider: "nebius",
  model_id: "meta-llama/Llama-3.3-70B-Instruct",
  prompt_template: default_prompt,
  active: true,
  is_default: true,
  kind: "persona"
)
# Only update the prompt on existing rows if it's still a previous default-shipped
# version — avoid overwriting a user's hand-tuned prompt. Bump this guard whenever
# we change the default prompt so re-seeds pick up the new one.
KNOWN_OLD_PROMPT_PREFIXES = [
  "You analyze website-visitor",            # earliest version
  "You are a behavioral classifier"         # all prompts from May 14 onwards
].freeze
default.save! if default.new_record? ||
                 default.prompt_template_was.nil? ||
                 KNOWN_OLD_PROMPT_PREFIXES.any? { |p| default.prompt_template_was.start_with?(p) }

# Clean up old Anthropic seed if it lingers from earlier dev.
ModelConfig.where(name: "claude-default").destroy_all

puts "Seeded ModelConfig: #{ModelConfig.pluck(:name).inspect}"
