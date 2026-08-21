class Publisher < ApplicationRecord
  has_many :books, dependent: :nullify
end
