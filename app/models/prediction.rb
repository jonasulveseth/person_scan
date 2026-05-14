class Prediction < ApplicationRecord
  belongs_to :visitor
  belongs_to :model_config
end
