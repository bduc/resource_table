class Author < ApplicationRecord
  has_many :books, dependent: :destroy
  has_many :reviews, through: :books
  has_many :author_settings, dependent: :destroy
end
