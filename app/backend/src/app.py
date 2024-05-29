from flask import Flask, request, jsonify # type: ignore
from flask_cors import CORS # type: ignore

app = Flask(__name__)

CORS(app, resources={r"/*": {"origins": "*"}})

players = []
board = ['', '', '', '', '', '', '', '', '']
current_player_symbol = 'X'
current_player = ''
first_assign_current_player = True
winner = ''
draw = False

@app.route("/")
def hello_world():
    return f"<h1>this is backend</h1>"

@app.route("/create_room", methods=['POST'])
def create_room():
    data = request.json
    username = data.get('username')

    if not username:
        return jsonify({'success': False, 'message': "Username cannot be empty!"})
    
    if len(players) >= 2:
        return jsonify({'success': False, 'message': "Room is full!"})
    
    if username in players:
        return jsonify({'success': False, 'message': "This username already exists in the room!"})
    
    players.append(username)
    
    global current_player
    current_player = players[0]
    
    return jsonify({
        'success': True,
        "player_1": players[0],
        "player_2": players[1] if len(players) == 2 else "",
        "current_player": current_player
    })

@app.route('/get_users')
def get_users():
    if len(players) == 2:
        return {
            "player_1": players[0],
            "player_2": players[1],
        }
    return {"player_1": players[0], "player_2": ""}

@app.route('/game_state')
def game_state():
    global current_player
    global board
    return jsonify({
        'board': board,
        'current_player': current_player
    })

@app.route('/make_move', methods=['POST'])
def make_move():
    global current_player_symbol
    global current_player
    global board
    global winner
    global draw
    
    if winner or draw:
        return jsonify({'success': False, 'message': 'Game has already ended'})
    try:
        data = request.json
        index = data.get('index')
        username = data.get('username')
        if len(players) == 2:
            if current_player == username:
                if not board[index]:
                    board[index] = current_player_symbol
                    if check_win() or check_draw():
                        winner = current_player if check_win() else None
                        draw = check_draw()
                    else:
                        current_player_symbol = 'O' if current_player_symbol == 'X' else 'X'
                        current_player = players[1] if current_player_symbol == 'O' else players[0]
                    return jsonify({'success': True, 'board': board, 'current_player': current_player})
                else:
                    return jsonify({'success': False, 'message': 'Invalid move'})
            else:
                return jsonify({'success': False, 'message': 'Not your turn'})
        else:
            return jsonify({'success': False, 'message': 'Game not started yet'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

@app.route('/check_game_state')
def check_game_state():
    winner = current_player if check_win() else None
    draw = check_draw()
    return jsonify({'winner': winner, 'draw': draw})

def check_win():
    winning_conditions = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6]            
    ]
    for condition in winning_conditions:
        if all(board[i] == board[j] == board[k] and board[i] != '' for i, j, k in [condition]):
            return True
    return False

def check_draw():
    return all(cell != '' for cell in board)

@app.route('/reset_board')
def reset_board():
    global board, current_player_symbol, current_player, winner, draw
    board = ['', '', '', '', '', '', '', '', '']
    current_player_symbol = 'O' if current_player_symbol == 'X' else 'X'
    current_player = players[1] if current_player_symbol == 'O' else players[0]
    winner = ''
    draw = False
    return jsonify({'board': board, 'current_player': current_player})

if __name__ == "__main__":
    app.run(port=5000, host="0.0.0.0")
