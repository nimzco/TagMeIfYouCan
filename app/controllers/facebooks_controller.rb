require 'rack/oauth2'
require 'rdf'
require 'rdf/ntriples'
include RDF

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
      tag = Tag.create(:uri => params[:query_string], :name => name, :wikipedia_url => params[:tag][:wikipedia_url], :thumbnail => params[:tag][:thumbnail])
      tag.retrieve_info
    end

    TagsFacebook.create(:tag => tag, :from_facebook_identifier => current_user.identifier, :facebook_identifier => user_to_tag.identifier, :status => Status.pending)

    friend_identifier = params[:tag][:user_identifier]
    # Create friend and relation if doesn't exists yet
    begin
      graph = RDF::Graph.load(RDF_FILE_PATH, :format => :ntriples)
      # If friend doesn't exists in the graph
      if !graph.has_triple?([RDF::URI.new("http://www.facebook.com/" + friend_identifier), RDF.type, RDF::FOAF.person])
        RDF::Writer.open(RDF_FILE_PATH) do |writer|
          graph << [RDF::URI.new("http://www.facebook.com/" + friend_identifier), RDF.type, RDF::FOAF.person]            
          writer << graph
        end
      end
      if !graph.has_triple?([RDF::URI.new(current_user.uri), RDF::FOAF.knows, RDF::URI.new("http://www.facebook.com/" + friend_identifier)])
        RDF::Writer.open(RDF_FILE_PATH) do |writer|
          graph << [RDF::URI.new(current_user.uri), RDF::FOAF.knows, RDF::URI.new("http://www.facebook.com/" + friend_identifier)]
          graph << [RDF::URI.new("http://www.facebook.com/" + friend_identifier), RDF::FOAF.knows, RDF::URI.new(current_user.uri)]
          writer << graph
        end
      end
    rescue
        puts "An error occured - No such file" 
    end


    respond_to do |format|
      format.html { redirect_to root_path }
    end    
  end
  
  def accept_tag
    tag_facebook = TagsFacebook.where(:tag_id => params[:tag_id], :facebook_identifier => current_user.identifier).order("created_at DESC").first
    tag_facebook.accept
    
    respond_to do |format|
      format.html { redirect_to root_path }
    end
  end

  def decline_tag
    tag_facebook = TagsFacebook.where(:tag_id => params[:tag_id], :facebook_identifier => current_user.identifier).order("created_at DESC").first
    tag_facebook.decline
    respond_to do |format|
      format.html { redirect_to root_path }
    end
  end

  def return_tag
    tag_facebook = TagsFacebook.where(:tag_id => params[:tag_id], :facebook_identifier => current_user.identifier).order("created_at DESC").first
    tag_facebook.accept

    TagsFacebook.create(:tag_id => params[:tag_id], :from_facebook_identifier => current_user.identifier, :facebook_identifier => params[:to_facebook_identifier])
    respond_to do |format|
      format.html { redirect_to root_path }
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
    client = Facebook.auth(callback_facebook_url).client
    client.authorization_code = params[:code]
    access_token = client.access_token!
    user = FbGraph::User.me(access_token).fetch
    fb_user = Facebook.identify(user)
    fb_user.uri = "http://www.facebook.com/#{user.identifier}"
    fb_user.save

    authenticate fb_user
    
    friends = user.friends
    # Defining facebook people as fb_person
    begin
      graph = RDF::Graph.load(RDF_FILE_PATH, :format => :ntriples)
      # If user doesn't exists in the graph
      if !graph.has_triple?([RDF::URI.new(fb_user.uri), RDF.type, RDF::FOAF.person])
        RDF::Writer.open(RDF_FILE_PATH) do |writer|
          graph << [RDF::URI.new(fb_user.uri), RDF.type, RDF::FOAF.person]
          writer << graph
        end
      end
      RDF::Writer.open(RDF_FILE_PATH) do |writer|
        # Create friends relations if doesn't exists yet
        friends.each do |friend|
          # If friend doesn't exists in the graph
          friend_triple = [RDF::URI.new("http://www.facebook.com/" + friend.identifier), RDF.type, RDF::FOAF.person]
          if !graph.has_triple?(friend_triple)
            RDF::Writer.open(RDF_FILE_PATH) do |writer|
              graph << friend_triple
            end
          end
          friend_relation_triple = [RDF::URI.new(fb_user.uri), RDF::FOAF.knows, RDF::URI.new("http://www.facebook.com/" + friend.identifier)]
          if !graph.has_triple?(friend_relation_triple)
            RDF::Writer.open(RDF_FILE_PATH) do |writer|
              graph << friend_relation_triple
              graph << [RDF::URI.new("http://www.facebook.com/" + friend.identifier), RDF::FOAF.knows, RDF::URI.new(fb_user.uri)]
            end
          end
        end
        writer << graph
      end
    rescue
        puts "An error occured - No such file" 
    end

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

#           graph << [RDF::URI.new(fb_user.uri), RDF.type, RDF::FOAF.person]
#           friends.each do |friend|
#             graph << [RDF::URI.new(fb_user.uri), RDF::FOAF.knows, RDF::URI.new("http://www.facebook.com/" + friend.identifier)]
# 
#             # Put in the graph that the friend is a person if doesn't exists in the triple file
#             # if !graph.has_triple?([RDF::URI.new("http://www.facebook.com/" + friend.identifier), RDF.type, RDF::FOAF.person])
#             #   graph << [RDF::URI.new("http://www.facebook.com/" + friend.identifier), RDF.type, RDF::FOAF.person] 
#             # end            
#           end
#           writer << graph
#         end
#       else
#         RDF::Writer.open('app/assets/rdf/people-film.nt') do |writer|
#           # Will create a node for friend if he doesn't exists yet
#           friends.each do |friend|
#             if !graph.has_triple?([RDF::URI.new("http://www.facebook.com/" + friend.identifier), RDF.type, RDF::FOAF.person])
#               graph << [RDF::URI.new("http://www.facebook.com/" + friend.identifier), RDF.type, RDF::FOAF.person]            
#             end          
#             if !graph.has_triple?([RDF::URI.new(fb_user.uri), RDF::FOAF.knows, RDF::URI.new("http://www.facebook.com/" + friend.identifier)])
#               graph << [RDF::URI.new(fb_user.uri), RDF::FOAF.knows, RDF::URI.new("http://www.facebook.com/" + friend.identifier)]
#             end
#           end
#           writer << graph
#         end
