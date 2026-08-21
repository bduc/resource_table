class Book < ApplicationRecord
  belongs_to :author
  belongs_to :publisher, optional: true
  has_many :reviews, dependent: :destroy
end
