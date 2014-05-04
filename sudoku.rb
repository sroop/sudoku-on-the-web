require 'sinatra' 
require_relative './lib/sudoku'
require_relative './lib/cell'
require 'sinatra/partial' 
require 'rack-flash'

enable :sessions
set :session_secret, '*&(^B234'
set :partial_template_engine, :erb
use Rack::Flash

def random_sudoku
  seed = (1..9).to_a.shuffle + Array.new(81-9, 0)
  sudoku = Sudoku.new(seed.join)
  sudoku.solve!
  sudoku.to_s.chars
end

def contains_nine_zeros?(array)
  newarray = array.select {|number| number == "0"}
  newarray.count == 9
end

def puzzle(sudoku, level=3)
  kinda_empty_sudoku = sudoku.dup
  until contains_nine_zeros?(kinda_empty_sudoku) do
    kinda_empty_sudoku = sudoku.dup
    boxes = boxes(kinda_empty_sudoku).each{|box|
        box[rand(9)]="0" if !box.include?("0") }
    rows = rows(boxes.flatten).each {|row|
        row[rand(9)]="0" if !row.include?("0")}
    cols = columns(rows.flatten).each {|col|
        col[rand(9)]="0" if !col.include?("0")}
    kinda_empty_sudoku = cols.transpose.flatten
  end
  boxes(kinda_empty_sudoku).flatten
end

def box_order_to_row_order(sudoku)
    boxes = boxes(sudoku)
    (0..8).to_a.inject([])  { |memo, i| 
    first_box_index = i / 3 * 3
    three_boxes = boxes[first_box_index, 3]
    three_rows_of_three = three_boxes.map { |box| 
        row_number_in_a_box = i % 3
        first_cell_in_the_row_index = row_number_in_a_box * 3
        box[first_cell_in_the_row_index, 3] }
    memo += three_rows_of_three.flatten
  } 
end

def rows(sudoku)
  box_order_to_row_order(sudoku).each_slice(9).to_a
end

def columns(sudoku)
  rows(sudoku).transpose
end

def boxes(sudoku)
  sudoku.each_slice(9).to_a
end

get '/' do # default route for our website
  prepare_to_check_solution
  generate_new_puzzle_if_necessary
  set_session_variables
  erb :index
end

def level_generator(level)
  session.clear()
  sudoku = random_sudoku
  session[:solution] = sudoku
  session[:puzzle] = puzzle(sudoku, level)
  session[:current_solution] = session[:puzzle]
  set_session_variables
  erb :index
end

post '/easy' do
  level_generator(2)
end

post '/medium' do
  level_generator(40)
end

post '/hard' do
  level_generator(100)
end

post '/restart' do
  session[:current_solution] = session[:puzzle]
  set_session_variables
  erb :index
end

def set_session_variables
  @current_solution = session[:current_solution] || session[:puzzle]
  @solution = session[:solution]
  @puzzle = session[:puzzle]
end

def generate_new_puzzle_if_necessary
  return if session[:current_solution] && session[:solution] && session[:puzzle] 
  sudoku = random_sudoku
  session[:solution] = sudoku
  session[:puzzle] = puzzle(sudoku)
  session[:current_solution] = session[:puzzle]
end

def prepare_to_check_solution
  @check_solution = session[:check_solution]
  if @check_solution
    flash[:notice] = "Incorrect values are highlighted in yellow"
  end
  session[:check_solution] = nil
end

post '/solution' do
  redirect to("/solution")
end

get '/solution' do
  @current_solution = session[:solution]
  @solution = @current_solution
  @puzzle = []
  erb :index
end

post '/' do
  cells = box_order_to_row_order(params["cell"])
  session[:current_solution] = cells.map { |value| value.to_i }.join
  session[:check_solution] = true
  redirect to("/")
end

helpers do

  def colour_class(solution_to_check, puzzle_value, current_solution_value, solution_value)
    must_be_guessed = puzzle_value.to_i == 0
    tried_to_guess = current_solution_value.to_i != 0
    guessed_incorrectly = current_solution_value != solution_value

    if solution_to_check && 
      must_be_guessed &&
      tried_to_guess &&
      guessed_incorrectly
      "incorrect"
    elsif !must_be_guessed
      "value-provided"
    end
  end

  def cell_value(value)
    value.to_i == 0 ? '' : value
  end

  def read_only?(cell)
    cell.to_i == 0 ? cell : 'readonly'
  end

end


# this is the link we read to solve our session problem: 
# http://stackoverflow.com/questions/18044627/sinatra-1-4-3-use-racksessioncookie-warning