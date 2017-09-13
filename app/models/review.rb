class Review < ApplicationRecord
  belongs_to :language
  validates :content, length: { minimum: 20 }
end
