class Review < ApplicationRecord
  belongs_to :language, touch: true # Let the parent know something changed! 
  validates :content, length: { minimum: 10 }
end
