class Language < ApplicationRecord
  has_many :reviews 
  validates :name, :description, presence: true
end
