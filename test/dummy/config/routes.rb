Rails.application.routes.draw do
  mount ResourceTable::Engine => "/resource_table"

  # Minimal show routes so the dummy app can exercise `link: :self`
  # (_cell.html.erb) and the lookup_one specialisation's link to the
  # associated record (_lookup_one.html.erb) without url_for raising.
  # :index is also needed so a sortable header's
  # url_for(request.query_parameters.merge(...)) (_head.html.erb) has a
  # route to recall onto — the same recall mechanism a real index action
  # gets for free from its own current request.
  resources :books, only: [ :show, :index ]
  resources :authors, only: [ :show ]
end
