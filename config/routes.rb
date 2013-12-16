Frustration::Application.routes.draw do


  # root
  root to: 'top#index'

  #-----------------------------------------------
  # web
  #-----------------------------------------------
  # login/out
  get 'login',                    to: 'sessions#new',     as: :login
  get 'logout',                   to: 'sessions#destroy', as: :logout
  get '/auth/:provider/callback', to: 'sessions#create'
  resources :sessions, only: %w[new create destroy]

  # sign up
  resources :users, only: [:new, :create]
  resources :friendships, only: [:create] do
    delete 'delete', on: :collection
  end

  # users
  scope '/users/:username', as: :users do
    get '/', to: 'users#show'
    get '/followings', to: 'friendships#followings'
    get '/followers',  to: 'friendships#followers'
  end

  scope '/password/', as: :passwords do
    get   '/',         to: 'password#index'
    post  '/sendmail', to: 'password#sendmail'
    get   '/reset',    to: 'password#reset'
    patch '/finish',   to: 'password#finish'
  end

  # items
  resources :items, only: [:show] do
    resources :comments, only: [:index]
  end

  # home
  get 'home', to: 'home#index'

  # setting
  scope '/settings', as: :settings do
    get   '/icon',    to: 'settings#icon'
    get   '/profile', to: 'settings#profile'
    patch '/profile', to: 'settings#profile_update'
    resources :categories
    resources :comments
  end

  match 'fumans/',                 to: 'fumans#index',      via: [:get, :post]
  match 'fumans/search',           to: 'fumans#search',     via: [:get, :post]
  match 'fumans/categories/:type', to: 'fumans#categories', via: :get
  resources :fumans, :only => [:index, :new, :update, :destroy] do
    collection do
      get 'itunes'
      post 'create_with_item'
    end
  end

  #-----------------------------------------------
  # api
  #-----------------------------------------------
  namespace :api, defaults: {format: :json} do
    get '/public_timeline' , to: 'media#public_timeline'

    scope '/me/' do
      resources :categories
    end

    resources :sessions, only: [:create]
    resources :items,    only: [:show]
    resources :users,    only: [:create, :destroy, :show] do
      get  'friends_timeline',  to: 'users#friends_timeline'
      get  'user_timeline',     to: 'users#user_timeline'


      resources :friendships, only: [:create, :destroy]
      resources :friends,     only: [:index]
      resources :followers,   only: [:index]

    end

    resources :fumans do
      get 'statuses', on: :collection
    end
  end
end
