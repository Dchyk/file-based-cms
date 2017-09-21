ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms.rb"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin"} }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_text_document
    create_document "history.txt", "earth was in darkness"

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal true, last_response.body.include?("earth was in darkness")
  end

  def test_file_error
    get "/not_a_file.txt" 

    assert_equal 302, last_response.status

    assert_equal "The file 'not_a_file.txt' does not exist.", session[:message]
  end

  def test_viewing_markdown_document
    create_document "about.md", "# Ruby is..."

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_editing_document
    create_document "about.md"

    get "about.md/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_editing_document_not_signed_in
    create_document "about.md"

    get "about.md/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    post "/changes.txt", {content: "new content"}, admin_session

    assert_equal 302, last_response.status

    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_updating_document_not_signed_in
    post "/changes.txt", {content: "new content"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_document_form_not_signed_in
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document
    post "/create", {file_name: "test.txt"}, admin_session
    assert_equal 302, last_response.status

    assert_equal "test.txt has been created.", session[:message]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_not_signed_in
    post "/create", {file_name: "test.txt"}
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document_without_filename
    post "/create", {file_name: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_create_new_document_with_invalid_extension
    post "/create", {file_name: "test.jpg"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "Invalid filename - name can't be blank and files must be either *.md or *.txt.", session[:message]
  end

  def test_delete_document
    create_document("test.txt")

    post "/test.txt/delete", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="test.txt")
  end

  def test_delete_document_not_signed_in
    create_document("test.txt")
    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "test", password: "test"
    assert_equal 442, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    get "/", {}, {"rack.session" => { username: "admin"}}
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    get last_response["Location"]

    assert_nil session[:username]
    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Sign In"
  end

  def test_duplicate_file
    create_document("test.txt")
    post "/test.txt/duplicate", {}, {"rack.session" => { username: "admin"}}

    assert_equal 302, last_response.status
    assert_equal "'test.txt' has been duplicated as 'test-copy1.txt'.", session[:message]

    get "/"
    assert_includes last_response.body, "test-copy1.txt"
  end

  def test_create_and_login_new_user
    # Skipped, otherwise the test fails because the username it creates is still 
    # in the testing yaml file
    skip
    post "/users/create", { username: "user1", password: "pass1" }

    assert_equal 302, last_response.status
    assert_equal "User 'user1' successfully created.", session[:message]

    post "/users/signin", username: "user1", password: "pass1"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "user1", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as user1"
  end

  def test_create_user_with_existing_name
    post "/users/create", { username: "admin", password: "pass2" }

    assert_equal 302, last_response.status
    assert_equal "That username already exists! Username must be unique.", session[:message]
  end

  def test_uploading_image_file
    skip
    post "/save_image", "image_file" => Rack::Test::UploadedFile.new("me.jpg", "image/jpeg")
    # Create an image file for testing
    # Test the success message?

  end

  def test_uploading_invalid_image_filetype

  end

  def test_delete_image

  end
end