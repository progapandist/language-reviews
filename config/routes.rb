Rails.application.routes.draw do
  root to: 'languages#index'
  resources :languages, only: [ :index, :show ] do
    resources :reviews, only: [ :create ]
  end
  resources :reviews, only: [ :destroy ]
end
