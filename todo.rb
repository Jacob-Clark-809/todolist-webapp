require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists
end

# Render the new list form
get "/lists/new" do
  erb :new_list
end

# View a single list
get "/lists/:id" do
  @current_list = session[:lists][params[:id].to_i]
  erb :list
end

# Render the edit list form
get "/lists/:id/edit" do
  @current_list = session[:lists][params[:id].to_i]
  erb :edit_list
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Edit a list
post "/lists/:id" do
  @current_list = session[:lists][params[:id].to_i]
  new_name = params[:list_name].strip
  error = error_for_list_name(new_name)

  if error
    session[:error] = error
    erb :edit_list
  else
    @current_list[:name] = new_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{params[:id]}"
  end
end

# Delete a list
post "/lists/:id/destroy" do
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a todo to a list
post "/lists/:id/todos" do
  id = params[:id].to_i
  @current_list = session[:lists][id]
  todo_name = params[:todo].strip
  error = error_for_todo_name(todo_name)

  if error
    session[:error] = error
    erb :list
  else
    @current_list[:todos] << { name: todo_name, completed: false }
    session[:success] = "The todo was added."
    redirect "lists/#{id}"
  end
end

# Delete a todo from the list
post "/lists/:id/todos/:todo_id/destroy" do
  session[:lists][params[:id].to_i][:todos].delete_at(params[:todo_id].to_i)
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{params[:id]}"
end

# Mark a todo as complete/incomplete
post "/lists/:id/todos/:todo_id" do
  is_completed = params[:completed] == "true"
  @current_list = session[:lists][params[:id].to_i]
  @current_todo = @current_list[:todos][params[:todo_id].to_i]
  @current_todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{params[:id]}"
end

# Complete all todos in a list
post "/lists/:id/complete_all" do
  @current_list = session[:lists][params[:id].to_i]
  @current_list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{params[:id]}"
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "The list name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name already in use."
  end
end

# Return an error message if todo name is invalid. Return nil otherwise
def error_for_todo_name(name)
  if !(1..100).cover?(name.size)
    "The todo name must be between 1 and 100 characters."
  elsif @current_list[:todos].any? { |todo| todo[:name] == name }
    "That todo already exists."
  end
end

helpers do
  def list_class(list)
    unless list[:todos].any? { |todo| todo[:completed] == false } ||
      list[:todos].size == 0
      "complete"
    end
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_completed_count(list)
    list[:todos].count { |todo| todo[:completed] == true }
  end

  def lists_in_order(lists)
    complete_lists, incomplete_lists = lists.partition do |list|
      list_class(list) == "complete"
    end

    incomplete_lists.each { |list| yield(list, lists.index(list)) }
    complete_lists.each { |list| yield(list, lists.index(list)) }
  end

  def todos_in_order(todos)
    complete_todos, incomplete_todos = todos.partition do |todo|
      todo[:completed]
    end

    incomplete_todos.each { |todo| yield(todo, todos.index(todo)) }
    complete_todos.each { |todo| yield(todo, todos.index(todo)) }
  end
end