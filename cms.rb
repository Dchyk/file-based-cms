require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'pry'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

def user_is_signed_in?
  session.key?(:username)
end

def requre_signed_in_user
  unless user_is_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end 
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |filename|
    File.basename(filename)
  end
  erb :index, layout: :layout
end

get "/new" do
  requre_signed_in_user

  erb :new
end

post "/create" do
  requre_signed_in_user

  filename = params[:file_name].to_s


  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")
    session[:message] = "#{params[:file_name]} has been created."

    redirect "/"
  end
end

get "/:file_name" do
  file_path = File.join(data_path, params[:file_name])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "The file '#{params[:file_name]}' does not exist."
    redirect "/"
  end
end

get "/:file_name/edit" do
  requre_signed_in_user

  @file_name = params[:file_name]
  file_path = File.join(data_path, params[:file_name])

  @content = File.read(file_path)
  erb :edit
end

post "/users/signin" do
  username = params[:username]
  password = params[:password]

  if username == "admin" && password == "secret"
    session[:username] = username
    session[:message]  = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 442
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

post "/:file_name" do
  requre_signed_in_user

  file_path = File.join(data_path, params[:file_name])
  File.write(file_path, params[:content])

  session[:message] = "#{params[:file_name]} has been updated."
  redirect "/"
end

post "/:file_name/delete" do 
  requre_signed_in_user

  file_path = File.join(data_path, params[:file_name])
  File.delete(file_path)

  session[:message] = "#{params[:file_name]} has been deleted."
  redirect "/"
end

get "/users/signin" do

  erb :signin
end

