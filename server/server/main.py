import asyncio
import websockets
import json
import time
import uuid
import random
import os

GRID_WIDTH = 20
GRID_HEIGHT = 15
BOMB_TIMER = 3
BLAST_RADIUS = 2
GAME_TICK_RATE = 1 / 60
MIN_PLAYERS_TO_START = 2
GAME_OVER_DURATION = 5
ROUND_DURATION = 120
ENDGAME_BOMB_CHANCE = 0.004

AVAILABLE_MAPS = {}

def load_maps():
    maps_dir = "maps"
    if not os.path.exists(maps_dir):
        print(f"CRITICAL ERROR: Directory '{maps_dir}' not found!")
        exit()
        
    for filename in os.listdir(maps_dir):
        if filename.endswith(".txt"):
            try:
                with open(os.path.join(maps_dir, filename), 'r') as f:
                    map_data = [list(row) for row in f.read().strip().split('\n')]
                    if len(map_data) == GRID_HEIGHT and all(len(row) == GRID_WIDTH for row in map_data):
                        map_name = os.path.splitext(filename)[0]
                        AVAILABLE_MAPS[map_name] = map_data
                        print(f"Map '{map_name}' loaded successfully.")
                    else:
                        print(f"Error: Map '{filename}' has incorrect dimensions.")
            except Exception as e:
                print(f"Failed to load map '{filename}': {e}")

    if not AVAILABLE_MAPS:
        print("CRITICAL ERROR: No valid maps found! Cannot start the game.")
        exit()

class Player:
    def __init__(self, id, name, start_x, start_y):
        self.id, self.name = id, name
        self.start_x, self.start_y = start_x, start_y
        self.x, self.y = start_x, start_y
        self.alive = True
        self.ready = False

    def move(self, dx, dy, game):
        if not self.alive: 
            return

        new_x, new_y = self.x + dx, self.y + dy
        
        if not (0 <= new_x < GRID_WIDTH and 0 <= new_y < GRID_HEIGHT):
            return

        target_tile = game.map[new_y][new_x]
        
        allowed_tiles = [' ', 'p']
        if target_tile not in allowed_tiles:
            return
            
        self.x, self.y = new_x, new_y

    def reset(self, start_x, start_y):
        self.start_x, self.start_y = start_x, start_y
        self.x, self.y = self.start_x, self.start_y
        self.alive = True
        self.ready = False

    def to_dict(self):
        return {"id": self.id, "name": self.name, "x": self.x, "y": self.y, "alive": self.alive, "ready": self.ready}

class Bomb:
    def __init__(self, x, y):
        self.x, self.y = x, y
        self.place_time = time.time()
    
    def is_expired(self): return time.time() - self.place_time > BOMB_TIMER
    def to_dict(self): return {"x": self.x, "y": self.y}

class Game:
    def __init__(self):
        self.players = {}
        self.events_to_send = []
        self.reset()

    def reset(self):
        map_name, map_layout = random.choice(list(AVAILABLE_MAPS.items()))
        
        self.original_map = [list(row) for row in map_layout]
        self.map = [list(row) for row in self.original_map]
        
        self.bombs = []
        self.state = "WAITING"
        self.winner, self.game_over_time, self.round_start_time = None, None, None
        
        available_starts = self._find_start_positions()
        random.shuffle(available_starts)
        
        for player in self.players.values():
            if available_starts:
                start_pos = available_starts.pop(0)
                player.reset(start_pos[0], start_pos[1])
            else:
                player.alive = False

    def _find_start_positions(self):
        return [(x, y) for y, row in enumerate(self.original_map) for x, tile in enumerate(row) if tile == 'p']

    def add_player(self, player_id, player_name):
        taken_starts = {(p.start_x, p.start_y) for p in self.players.values()}
        free_starts = [pos for pos in self._find_start_positions() if pos not in taken_starts]
        
        if not free_starts:
            return None
            
        start_pos = free_starts[0]
        player = Player(player_id, player_name, start_pos[0], start_pos[1])
        self.players[player_id] = player
        return player

    def remove_player(self, player_id):
        if player_id in self.players:
            self.players.pop(player_id)
            self.check_game_start()

    def handle_input(self, player_id, action):
        player = self.players.get(player_id)
        if not player: return

        if self.state == "WAITING":
            if action['type'] == 'ready':
                player.ready = not player.ready
                self.check_game_start()

        if self.state == "IN_PROGRESS" and player.alive:
            if action['type'] == 'move': player.move(action['dx'], action['dy'], self)
            elif action['type'] == 'place_bomb': self.place_bomb(player.x, player.y)

    def place_bomb(self, x, y):
        if not any(b.x == x and b.y == y for b in self.bombs): self.bombs.append(Bomb(x, y))

    def update(self):
        self.events_to_send.clear()

        if self.state == "GAME_OVER":
            if time.time() - self.game_over_time > GAME_OVER_DURATION: self.reset()
        elif self.state == "IN_PROGRESS":
            self.update_bombs()
            self.check_win_condition()

    def check_game_start(self):
        if self.state == "WAITING" and len(self.players) >= MIN_PLAYERS_TO_START:
            self.state = "IN_PROGRESS"
            self.round_start_time = time.time()

    def check_win_condition(self):
        alive_players = [p for p in self.players.values() if p.alive]
        if self.state == "IN_PROGRESS" and len(alive_players) < 1:
            self.state = "GAME_OVER"
            self.game_over_time = time.time()
            self.winner = "НИЧЬЯ"

    def update_bombs(self):
        for bomb in [b for b in self.bombs if b.is_expired()]:
            self.bombs.remove(bomb)
            affected_cells = self.process_server_side_explosion(bomb.x, bomb.y)
            explosion_event = {
                "type": "explosion_event",
                "payload": {
                    "cells": [{"x": x, "y": y} for x, y in affected_cells]
                }
            }
            self.events_to_send.append(explosion_event)

    def process_server_side_explosion(self, start_x, start_y):
        affected_cells = []
        
        def add_and_check(x, y):
            if (x, y) not in affected_cells:
                affected_cells.append((x, y))
                self._check_collisions(x, y)

        add_and_check(start_x, start_y)
        
        for dx, dy in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
            for i in range(1, BLAST_RADIUS + 1):
                x, y = start_x + dx * i, start_y + dy * i
                if not (0 <= x < GRID_WIDTH and 0 <= y < GRID_HEIGHT and self.map[y][x] != '#'):
                    break
                
                add_and_check(x, y)
                
                if self.map[y][x] == '.':
                    self.map[y][x] = ' '
                    break
        
        return affected_cells

    def _check_collisions(self, x, y):
        for player in self.players.values():
            if player.alive and player.x == x and player.y == y:
                player.alive = False

    def get_state(self):
        time_remaining = None
        if self.state == "IN_PROGRESS" and self.round_start_time:
            time_remaining = ROUND_DURATION - (time.time() - self.round_start_time)
        return {
            "state": self.state,
            "winner": self.winner,
            "time_remaining": time_remaining,
            "map": self.map,
            "players": [p.to_dict() for p in self.players.values()],
            "bombs": [b.to_dict() for b in self.bombs]
        }

PLAYER_CLIENTS = {}

load_maps()
GAME = Game()

async def broadcast_state():
    if not PLAYER_CLIENTS: return

    if GAME.events_to_send:
        event_batch = json.dumps(GAME.events_to_send)
        clients = list(PLAYER_CLIENTS.values())
        if clients:
            await asyncio.gather(*[client.send(event_batch) for client in clients], return_exceptions=True)

    state = GAME.get_state()
    message = json.dumps({"type": "game_state", "payload": state})
    clients = list(PLAYER_CLIENTS.values())
    if not clients: return
    await asyncio.gather(*[client.send(message) for client in clients], return_exceptions=True)

async def game_loop():
    while True:
        GAME.update()
        await broadcast_state()
        await asyncio.sleep(GAME_TICK_RATE)

async def handler(websocket):
    client_id = str(uuid.uuid4())
    try:
        message = await websocket.recv()
        data = json.loads(message)
        
        if data.get("type") == "join" and data.get("role") == "player":
            player_name = data.get("name", "Anonymous")
            if GAME.add_player(client_id, player_name) is None:
                await websocket.close(code=1008, reason="Server is full")
                return
            
            PLAYER_CLIENTS[client_id] = websocket
            await websocket.send(json.dumps({"type": "assign_id", "payload": client_id}))
            GAME.check_game_start()
        else:
            return

        async for message in websocket:
            action = json.loads(message)
            GAME.handle_input(client_id, action)

    except (websockets.exceptions.ConnectionClosed, json.JSONDecodeError):
        pass
    finally:
        if client_id in PLAYER_CLIENTS:
            del PLAYER_CLIENTS[client_id]
            GAME.remove_player(client_id)

async def main():
    asyncio.create_task(game_loop())
    async with websockets.serve(handler, "0.0.0.0", 8765):
        await asyncio.Future()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass