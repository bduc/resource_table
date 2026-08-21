class Author < ApplicationRecord
  has_many :books, dependent: :destroy
  has_many :reviews, through: :books
end
