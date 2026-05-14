class ClickEvent < ApplicationRecord
  belongs_to :visitor
  belongs_to :site
end
