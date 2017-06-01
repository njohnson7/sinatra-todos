require 'tilt/erubis'
require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
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
    # sort(lists) { |list, _| list_complete?(list) ? 1 : 0 }.each(&block)
    lists.sort_by { |list| list_complete?(list) ? 1 : 0 }.each(&block)
  end

  def sort_todos(todos, &block)
    # sort(todos) { |todo, _| todo[:completed] ? 1 : 0 }.each(&block)
    todos.sort_by { |todo| todo[:completed] ? 1 : 0 }.each(&block)
  end

  # def sort(arr, &block)
  #   # arr.map.with_index { |elem, idx| [elem, idx] }.sort_by(&block)
  #   arr.sort_by(&block)
  # end

  def h(content)
    Rack::Utils.escape_html(content)
  end
end

def load_id_and_list
  list_id = params[:list_id]
  lists = session[:lists]
  unless list_id =~ /\A\d+\z/ && lists.map { |list| list[:id] }.include?(list_id.to_i)
    session[:error] = 'The specified list was not found.'
    redirect '/lists'
  end
  list_id = list_id.to_i
  list = lists.find { |list| list[:id] == list_id }
  [list_id, list]
end

def next_element_id(arr)
  max = arr.map { |elem| elem[:id] }.max || -1
  max + 1
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

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# get '/list_id_error' do
#   "Invalid list ID: #{params[:list_id].inspect}"
# end

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    lists = session[:lists]
    list_id = next_element_id(lists)
    lists << { id: list_id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# View a single todo list
get '/lists/:list_id' do
  @list_id, @list = load_id_and_list
  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:list_id/edit' do
  @list_id, @list = load_id_and_list
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post '/lists/:list_id' do
  list_name = params[:list_name].strip
  @list_id, @list = load_id_and_list

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
  @list_id = load_id_and_list.first
  session[:lists].delete_if { |list| list[:id] == @list_id }
  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    '/lists'
  else
    session[:success] = 'The list has been deleted.'
    redirect '/lists'
  end
end

# Add a new todo to a list
post '/lists/:list_id/todos' do
  @list_id, @list = load_id_and_list
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    todo_id = next_element_id(@list[:todos])
    @list[:todos] << { id: todo_id, name: text, completed: false }

    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id, @list = load_id_and_list

  todo_id = params[:todo_id].to_i
  @list[:todos].delete_if { |todo| todo[:id] == todo_id }

  if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'
    status 204
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{@list_id}"
  end
end

# Update status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id, @list = load_id_and_list

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post '/lists/:list_id/complete_all' do
  @list_id, @list = load_id_and_list

  @list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{@list_id}"
end
