require 'spec_helper'

describe "Zync Routing" do

  stub_controllers do |routes|
    Routes = routes
    Routes.draw do
      match '/sports', :to => 'sports#index'
      get '/team_stats(/:grouping)', :to => 'team_stats#index'
      post '/fetch', :to => "api#fetch"

      resources :players

      resources :seasons do
        collection do
          get :current
        end

        member do
          get :statistics
          match '/news', :to => "news#index"
        end
      end

      resources :teams do

        resources :players do
          resources :splits
          
          member do
            get :player_totals
          end
          
          collection do
            get :totals
          end
          
        end
      end

      scope '/:league_slug' do
        match '/news', :to => 'news#index'

        resources :teams

        scope'(/seasons/:season_id)' do
          resources :players
        end
      end

    end
  end

  let(:app) { Routes }
  let(:request) { Rack::MockRequest.new(app) }

  describe "Route Matches" do

    it "routes to explcit controller/action" do
      response = request.get('/sports')
      response.body.should == "sports#index"

      request.get('/team_stats').body.should == "team_stats#index"
    end

    it "routes post requests" do
      get_response = request.get('/fetch')
      get_response.status.should == 404
      get_response.body.should == "Not Found"

      post_response = request.post('/fetch')
      post_response.body.should == "api#fetch"
    end

    it "accepts optional parameters" do
      response = request.get('/team_stats/year')
      response.body.should == "team_stats#index"
    end

    context "within a scope" do

      it "prepends the scope to the path" do
        response = request.get('/nulayer/news')
        response.body.should == "news#index"
      end

      it "prepends the scope to resources" do
        response = request.get('/nulayer/teams/123')
        response.body.should == "teams#show"
      end

      context "with a nested scope" do

        it "prepends the nested scope only to routes within the nested scope definition" do
          response = request.get('/nulayer/players')
          response.body.should == "players#index"

          response = request.get('/nulayer/seasons/123/players')
          response.body.should == "players#index"

          response = request.get('/nulayer/seasons/123/players/456')
          response.body.should == "players#show"
        end

      end

    end

    context "Resourceful route" do

      it "routes to index" do
        response = request.get('/players')
        response.body.should == "players#index"
      end

      it "routes to show" do
        response = request.get('/players/100')
        response.body.should == "players#show"
      end

      context "collection nested" do

        it "creates a route for a nested collection" do
          response = request.get('/seasons/current')
          response.body.should == "seasons#current"
        end

      end

      context "member nested" do

        it "routes to a nested member" do
          response = request.get('/seasons/123/statistics')
          response.body.should == "seasons#statistics"
        end

        it "routes via a match" do
          response = request.get('/seasons/123/news')
          response.body.should == "news#index"
        end

      end

      context "Nested Resource" do

        it "routes to a nested resource" do
          response = request.get('/teams/1234/players/5678/splits')
          response.body.should == "splits#index"

          response = request.get('/teams/1234/players/5678/splits/1')
          response.body.should == "splits#show"
        end

        context "member nested" do

          it "routes to the nested member of the nested resource" do
            response = request.get('/teams/1234/players/5678/player_totals')
            response.body.should == "players#player_totals"
          end
          
        end

        context "collection nested" do

          it "routes to the nested member of the nested resource" do
            response = request.get('/teams/1234/players/totals')
            response.body.should == "players#totals"
          end
          
        end

      end

    end

  end

  context "Route does not exist" do

    it "returns a 404 response" do
      response = request.get('/foobar', {})
      response.status.should == 404
      response.body.should == "Not Found"
    end

  end

end
