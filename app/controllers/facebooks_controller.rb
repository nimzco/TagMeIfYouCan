require 'rack/oauth2'

class FacebooksController < ApplicationController
  before_filter :require_authentication, :only => :destroy

  rescue_from Rack::OAuth2::Client::Error, :with => :oauth2_error

  def tag
    user_to_tag = Facebook.where(:identifier => params[:tag][:user_identifier]).first
    if user_to_tag.nil? 
      user_to_tag = Facebook.create(:identifier => params[:tag][:user_identifier])
    end

    # Prevent from duplicating a tag
    tag = Tag.where(:uri => params[:query_string]).first
    if tag.nil?
      name = CGI.unescape(params[:query_string].gsub('_', ' ').gsub('http://dbpedia.org/resource/', ' '))
      tag = Tag.new(:uri => params[:query_string], :name => name, :wikipedia_url => params[:tag][:wikipedia_url])
    end

    if tag.save
      TagsFacebook.create(:tag => tag, :from_facebook_id => current_user.id, :facebook_id => user_to_tag.id)
      respond_to do |format|
        format.html { redirect_to root_path }
      end    
    else
      respond_to do |format|
        format.html { redirect_to root_path, :notice => 'You have to choose a tag' }
      end    
    end
  end
  
  # handle Facebook Auth Cookie generated by JavaScript SDK
  def show
    auth = Facebook.auth.from_cookie(cookies)
    authenticate Facebook.identify(auth.user)
    redirect_to root_url
  end

  # handle Normal OAuth flow: start
  def new
    client = Facebook.auth(callback_facebook_url).client
    redirect_to client.authorization_uri(
      :scope => Facebook.config[:scope]
    )
  end

  # handle Normal OAuth flow: callback
  def create
    debugger
    client = Facebook.auth(callback_facebook_url).client
    client.authorization_code = params[:code]
    access_token = client.access_token!
    user = FbGraph::User.me(access_token).fetch
    authenticate Facebook.identify(user)
    redirect_to root_url
  end

  def destroy
    unauthenticate
    redirect_to root_url
  end

  private

  def oauth2_error(e)
    flash[:error] = {
      :title => e.response[:error][:type],
      :message => e.response[:error][:message]
    }
    redirect_to root_url
  end
end