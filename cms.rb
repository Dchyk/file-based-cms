require 'yaml'

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'redcarpet'
require 'pry'
require 'bcrypt'
require "fileutils"

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
  @content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    @content
  when ".md"
    render_markdown(@content)
  when ".jpeg"
    erb :image
  end
end

def load_image_content(name)

end

def user_is_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_is_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end 
end

def get_credentials_path
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yaml", __FILE__)
  else
    File.expand_path("../users.yaml", __FILE__)
  end
end

def load_usernames
  YAML.load_file(get_credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_usernames

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def valid_filetype?(filename)
  filename.match(/\S[.](txt|md)\b/)
end

def valid_image_filetype?(filename)
  filename.match(/[.](jpg|jpeg|gif|png)\b/)
end

def require_valid_image_filetype(filename)
  unless valid_image_filetype?(filename)
    session[:message] = "Can't upload this image - must be *.jpg, *.jpeg, *.gif or *.png."
    status 422
    redirect "/upload_image"
  end
end

def return_images_in_public_folder
  pattern = File.join('./public/', "*")

end

def require_valid_filetype(filename)
  unless valid_filetype?(filename)
    session[:message] = "Invalid filename - name can't be blank and files must be either *.md or *.txt."
    status 422
    redirect "/new"
  end
end

def duplicate_file_name(filename)
  basename  = filename.split(".").first
  extension = File.extname(filename)

  add_number_to_filename(basename) + extension
end

def add_number_to_filename(filename)
  filenumber = filename.scan(/[0-9]/).join.to_i

  if filenumber > 0
    filenumber += 1
    new_copy_number = "copy" + filenumber.to_s
    filename.gsub(/copy\d*/, new_copy_number)
  else
    filename + "-copy1"
  end
end

get "/" do
  pattern = File.join(data_path, "*")

  @files = Dir.glob(pattern).map do |filename|
    File.basename(filename)
  end

  image_pattern = File.join('./public/', "*")

  # This could be done with #select valid images, and then #map
  @images = Dir.glob(image_pattern).map do |filename|
    File.basename(filename) if valid_image_filetype?(filename)
  end.compact

  erb :index, layout: :layout
end

get "/new" do
  require_signed_in_user

  erb :new
end

post "/create" do
  require_signed_in_user

  filename = params[:file_name].to_s.strip

  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    require_valid_filetype(filename)

    file_path = File.join(data_path, filename)

    File.write(file_path, "")
    session[:message] = "#{params[:file_name]} has been created."

    redirect "/"
  end
end

get "/upload_image" do
  require_signed_in_user

  erb :upload_image
end

post "/save_image" do
  if params[:image_file].nil?
    session[:message] = "You must select a file to upload."
    status 422
    erb :upload_image
  else
    @filename = params[:image_file][:filename]
    incoming_image_file = params[:image_file][:tempfile]

    require_valid_image_filetype(@filename)
  # how to make the file path work correctly?
  # new_file_path = File.join(data_path, @filename) 
    new_file_path = File.join('./public/', @filename) 
    
    File.open(new_file_path, 'wb') do |image|
      image.write(incoming_image_file.read)
    end

    session[:message] = "'#{@filename}' was successfully saved."
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
  require_signed_in_user

  @file_name = params[:file_name]
  file_path = File.join(data_path, params[:file_name])

  @content = File.read(file_path)
  erb :edit
end

post "/:file_name/duplicate" do
  require_signed_in_user

  old_file_path = File.join(data_path, params[:file_name])

  new_file_name = duplicate_file_name(params[:file_name])
  new_file_path = File.join(data_path, new_file_name)

  FileUtils.copy_file(old_file_path, new_file_path)

  session[:message] = "'#{params[:file_name]}' has been duplicated as '#{new_file_name}'."
  redirect "/"
end

post "/users/signin" do
  username = params[:username]
  password = params[:password]
  users = YAML.load_file("users.yaml")

  if valid_credentials?(username, password)
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
  require_signed_in_user

  file_path = File.join(data_path, params[:file_name])
  File.write(file_path, params[:content])

  session[:message] = "#{params[:file_name]} has been updated."
  redirect "/"
end

post "/:file_name/delete" do 
  require_signed_in_user

  file_path = File.join(data_path, params[:file_name])
  File.delete(file_path)

  session[:message] = "#{params[:file_name]} has been deleted."
  redirect "/"
end

post "/:file_name/delete_image" do 
  require_signed_in_user

  file_path = File.join('./public/', params[:file_name])
  File.delete(file_path)

  session[:message] = "#{params[:file_name]} has been deleted."
  redirect "/"
end

get "/users/signin" do

  erb :signin
end

get "/users/create" do

  erb :create_user
end

post "/users/create" do
  username = params[:username]
  password = params[:password]

  credentials = load_usernames


  if credentials.key?(username)
    session[:message] = "That username already exists! Username must be unique."
    redirect "/users/create"
  else
    credentials[username] = BCrypt::Password.create(password)
    
    File.open(get_credentials_path, "w") do |file|
      file.write(credentials.to_yaml)
    end

    session[:message] = "User '#{username}' successfully created."
    redirect "/"
    # Then save the username and password in users.yaml
    # Save a message saying username has been created in session
    # Redirect to homepage? Or, sign in automatically
  end
end
