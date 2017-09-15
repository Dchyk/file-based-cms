require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

root = File.expand_path("..", __FILE__)

get "/" do
  @files = Dir.glob(root + "/data/*").map do |filename|
    File.basename(filename)
  end
  erb :index
end



#get "/:file_name" do
#  @content = File.read(root + "/data/#{params[:file_name]}.txt")
#
#  erb :file_content, layout: :index
#end