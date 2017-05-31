require 'tilt/erubis'
require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    !list_empty?(list) && todos_remaining_count(list).zero?
  end

  def list_empty?(list)
    todos_count(list).zero?
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def list_class(list)
    'complete' if list_complete?(list)
  end

  def sort_lists(lists, &block)
    sort(lists) { |list, _| list_complete?(list) ? 1 : 0 }.each(&block)
  end

  def sort_todos(todos, &block)
    sort(todos) { |todo, _| todo[:completed] ? 1 : 0 }.each(&block)
  end

  def sort(arr, &block)
    arr.map.with_index { |elem, idx| [elem, idx] }.sort_by(&block)
  end

  # def sort_lists(lists, &block)
  #   lists.map.with_index { |list, idx| [list, idx] }
  #        .partition { |list, idx| !list_complete?(list) }
  #        .flatten(1).each(&block)
  # end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return an error message if list name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !name.size.between?(1, 100)
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# Return an error message if list name is invalid. Return nil if name is valid.
def error_for_todo(name)
  'Todo must be between 1 and 100 characters.' unless name.size.between?(1, 100)
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

get '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  # redirect '/lists' unless (0...session[:lists].size).cover?(@list_id)
  @list = session[:lists][@list_id]

  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:list_id/edit' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post '/lists/:list_id' do
  list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo list
post '/lists/:list_id/delete' do
  @list_id = params[:list_id].to_i
  session[:lists].delete_at(@list_id)
  session[:success] = 'The list has been deleted.'
  redirect '/lists'
end

# Add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: text, completed: false }
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  @list[:todos].delete_at(todo_id)

  session[:success] = 'The todo has been deleted.'
  redirect "/lists/#{@list_id}"
end

# Update status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{@list_id}"
end
