import asyncio
import websockets
import json
import time
import uuid
import random
import os

# --- Константы ---
GRID_WIDTH = 20
GRID_HEIGHT = 15
BOMB_TIMER = 3
BLAST_RADIUS = 2
GAME_TICK_RATE = 1 / 60
MIN_PLAYERS_TO_START = 2
GAME_OVER_DURATION = 5
ROUND_DURATION = 120 # 2 минуты
ENDGAME_BOMB_CHANCE = 0.004 # Шанс спавна случайной бомбы в конце игры
WIN_DELAY = 3 # Задержка перед завершением игры после смерти предпоследнего игрока

# Глобальный словарь для хранения загруженных карт
AVAILABLE_MAPS = {}

def load_maps():
    """Загружает все карты из папки /maps."""
    maps_dir = "maps"
    if not os.path.exists(maps_dir):
        print(f"КРИТИЧЕСКАЯ ОШИБКА: Папка '{maps_dir}' не найдена!")
        exit()
        
    for filename in os.listdir(maps_dir):
        if filename.endswith(".txt"):
            try:
                with open(os.path.join(maps_dir, filename), 'r') as f:
                    map_data = [list(row) for row in f.read().strip().split('\n')]
                    if len(map_data) == GRID_HEIGHT and all(len(row) == GRID_WIDTH for row in map_data):
                        map_name = os.path.splitext(filename)[0]
                        AVAILABLE_MAPS[map_name] = map_data
                        print(f"Карта '{map_name}' успешно загружена.")
                    else:
                        print(f"Ошибка: Карта '{filename}' имеет неверные размеры.")
            except Exception as e:
                print(f"Не удалось загрузить карту '{filename}': {e}")

    if not AVAILABLE_MAPS:
        print("КРИТИЧЕСКАЯ ОШИБКА: Ни одной корректной карты не найдено! Игра не может начаться.")
        exit()

# --- Игровые классы ---
class Player:
    def __init__(self, id, name, start_x, start_y, color=None):
        self.id, self.name = id, name
        self.start_x, self.start_y = start_x, start_y
        self.x, self.y = start_x, start_y
        self.alive = True
        self.ready = False
        self.color = color

    def move(self, dx, dy, game):
        if not self.alive: return
        new_x, new_y = self.x + dx, self.y + dy
        
        # Проверка границ
        if not (0 <= new_x < GRID_WIDTH and 0 <= new_y < GRID_HEIGHT):
            return

        # Проверка препятствий (можно ходить по пустоте, спавнам и выжженной земле, если она есть)
        target_tile = game.map[new_y][new_x]
        if target_tile not in [' ', 'p']:
            return
            
        self.x, self.y = new_x, new_y
            
    def reset(self, start_x, start_y):
        self.start_x, self.start_y = start_x, start_y
        self.x, self.y = self.start_x, self.start_y
        self.alive = True
        self.ready = False

    def to_dict(self):
        result = {"id": self.id, "name": self.name, "x": self.x, "y": self.y, "alive": self.alive, "ready": self.ready}
        if self.color:
            result["color"] = self.color
        return result

class Bomb:
    def __init__(self, x, y):
        self.x, self.y = x, y
        self.place_time = time.time()
    def is_expired(self): return time.time() - self.place_time > BOMB_TIMER
    def to_dict(self): return {"x": self.x, "y": self.y}

# Класс Explosion удален, так как мы используем событийную модель

class Game:
    def __init__(self):
        self.players = {}
        self.events_to_send = [] # Очередь событий (взрывы)
        self.reset()

    def reset(self):
        print("--- ПЕРЕЗАПУСК ИГРЫ ---")
        
        num_current_players = len(self.players)
        suitable_maps = []
        for name, layout in AVAILABLE_MAPS.items():
            if sum(row.count('p') for row in layout) >= num_current_players:
                suitable_maps.append((name, layout))

        if not suitable_maps:
            print(f"Предупреждение: не найдено карт для {num_current_players} игроков.")
            map_name, map_layout = random.choice(list(AVAILABLE_MAPS.items()))
        else:
            map_name, map_layout = random.choice(suitable_maps)

        print(f"--- Выбрана карта: {map_name} ---")
        self.original_map = [list(row) for row in map_layout]
        self.map = [list(row) for row in self.original_map]
        
        # Очищаем зону 3x3 вокруг каждого спавна от разрушаемых блоков
        self._clear_spawn_zones()
        
        self.bombs = []
        self.state = "WAITING"
        self.winner, self.game_over_time, self.round_start_time = None, None, None
        self.endgame_mode = False
        self.win_check_time = None  # Время когда зафиксирована победа (для задержки)
        
        self.available_starts = self._find_start_positions()
        random.shuffle(self.available_starts)
        
        for player in self.players.values():
            if self.available_starts:
                start_pos = self.available_starts.pop(0)
                player.reset(start_pos[0], start_pos[1])
            else:
                print(f"Не хватило места для игрока {player.name}.")
                player.alive = False

    def _find_start_positions(self):
        return [(x, y) for y, row in enumerate(self.original_map) for x, tile in enumerate(row) if tile == 'p']

    def _clear_spawn_zones(self):
        """Очищает зону 3x3 вокруг каждого спавна от разрушаемых блоков."""
        spawn_positions = self._find_start_positions()
        
        for spawn_x, spawn_y in spawn_positions:
            # Проходим по квадрату 3x3 вокруг спавна
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    x, y = spawn_x + dx, spawn_y + dy
                    
                    # Проверка границ карты
                    if 0 <= x < GRID_WIDTH and 0 <= y < GRID_HEIGHT:
                        # Заменяем разрушаемые блоки на пустое пространство
                        if self.map[y][x] == '.':
                            self.map[y][x] = ' '
                            self.original_map[y][x] = ' '
        
        print(f"--- Очищены зоны спавна для {len(spawn_positions)} точек ---")

    def add_player(self, player_id, player_name, color=None):
        all_starts = self._find_start_positions()
        taken_starts = {(p.start_x, p.start_y) for p in self.players.values()}
        free_starts = [pos for pos in all_starts if pos not in taken_starts]
        
        if not free_starts:
            print("Нет свободных мест для нового игрока.")
            return None
            
        start_pos = free_starts[0]
        player = Player(player_id, player_name, start_pos[0], start_pos[1], color=color)
        self.players[player_id] = player
        print(f"Игрок '{player_name}' ({player_id}) добавлен на {start_pos}")
        return player

    def remove_player(self, player_id):
        if player_id in self.players:
            player = self.players.pop(player_id)
            print(f"Игрок '{player.name}' ({player_id}) удален.")
            self.check_game_start()

    def handle_input(self, player_id, action):
        player = self.players.get(player_id)
        if not player: return

        if self.state == "WAITING":
            if action['type'] == 'ready':
                player.ready = not player.ready
                print(f"Игрок '{player.name}' изменил статус готовности на: {player.ready}")
                self.check_game_start()
            return

        if self.state == "IN_PROGRESS" and player.alive:
            if action['type'] == 'move': player.move(action['dx'], action['dy'], self)
            elif action['type'] == 'place_bomb': self.place_bomb(player.x, player.y)

    def place_bomb(self, x, y):
        if not any(b.x == x and b.y == y for b in self.bombs): self.bombs.append(Bomb(x, y))

    def update(self):
        # Очищаем события прошлого тика
        self.events_to_send.clear()

        if self.state == "GAME_OVER":
            if time.time() - self.game_over_time > GAME_OVER_DURATION: self.reset()
        elif self.state == "IN_PROGRESS":
            self.update_bombs()
            self.check_endgame()
            if self.endgame_mode: self.spawn_random_bomb()
            self.check_win_condition()

    def check_game_start(self):
        if self.state == "WAITING" and len(self.players) >= MIN_PLAYERS_TO_START:
            all_ready = all(p.ready for p in self.players.values())
            if all_ready:
                self.state = "IN_PROGRESS"
                self.round_start_time = time.time()
                print("--- ВСЕ ГОТОВЫ! ИГРА НАЧАЛАСЬ ---")

    def check_win_condition(self):
        alive_players = [p for p in self.players.values() if p.alive]
        
        if self.state != "IN_PROGRESS":
            return
            
        if len(alive_players) <= 1:
            if self.win_check_time is None:
                self.win_check_time = time.time()
                print(f"--- Победа зафиксирована, ожидание {WIN_DELAY} сек для анимации... ---")
            
            if time.time() - self.win_check_time >= WIN_DELAY:
                self.state = "GAME_OVER"
                self.game_over_time = time.time()
                self.endgame_mode = False
                self.win_check_time = None
                self.winner = alive_players[0].name if alive_players else "НИЧЬЯ"
                print(f"--- ИГРА ОКОНЧЕНА! ПОБЕДИТЕЛЬ: {self.winner} ---")
        else:
            self.win_check_time = None
            
    def are_all_bricks_destroyed(self):
        return not any('.' in row for row in self.map)

    def check_endgame(self):
        time_is_up = self.round_start_time and (time.time() - self.round_start_time > ROUND_DURATION)
        if not self.endgame_mode and (time_is_up or self.are_all_bricks_destroyed()):
            self.endgame_mode = True
            print("--- ЭНДГЕЙМ АКТИВИРОВАН ---")

    def spawn_random_bomb(self):
        if random.random() < ENDGAME_BOMB_CHANCE:
            empty_tiles = [(x, y) for y, row in enumerate(self.map) for x, tile in enumerate(row) if self.original_map[y][x] in [' ', 'p', '.']]
            if empty_tiles:
                x, y = random.choice(empty_tiles)
                self.place_bomb(x, y)

    # --- ЛОГИКА ВЗРЫВОВ (ВЗЯТО ИЗ КОДА №1) ---
    def update_bombs(self):
        for bomb in [b for b in self.bombs if b.is_expired()]:
            self.bombs.remove(bomb)
            
            # 1. Вычисляем все затронутые клетки
            affected_cells = self.process_server_side_explosion(bomb.x, bomb.y)
            
            # 2. Создаем событие с этим списком
            explosion_event = {
                "type": "explosion_event",
                "payload": {
                    "cells": [{"x": x, "y": y} for x, y in affected_cells]
                }
            }
            # Добавляем в очередь на отправку
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
                print(f"Игрок '{player.name}' погиб.")

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
            # Explosions больше нет в state, они летят через events_to_send
        }

# --- Логика WebSocket ---
PLAYER_CLIENTS = {}
SPECTATOR_CLIENTS = set()

load_maps()
GAME = Game()

async def broadcast_state():
    if not PLAYER_CLIENTS and not SPECTATOR_CLIENTS: return
    
    all_recipients = list(PLAYER_CLIENTS.values()) + list(SPECTATOR_CLIENTS)
    if not all_recipients: return

    # 1. Отправляем события (взрывы)
    if GAME.events_to_send:
        event_batch = json.dumps(GAME.events_to_send)
        await asyncio.gather(*[client.send(event_batch) for client in all_recipients], return_exceptions=True)

    # 2. Отправляем состояние
    state = GAME.get_state()
    message = json.dumps({"type": "game_state", "payload": state})
    await asyncio.gather(*[client.send(message) for client in all_recipients], return_exceptions=True)

async def game_loop():
    while True:
        GAME.update()
        await broadcast_state()
        await asyncio.sleep(GAME_TICK_RATE)

async def handler(websocket):
    client_id = None
    client_type = None
    try:
        message = await websocket.recv()
        data = json.loads(message)
        
        if data.get("type") == "join":
            role = data.get("role", "player")
            if role == "player":
                player_name = data.get("name", "Аноним")
                color_data = data.get("color")
                color = None
                if color_data:
                    color = {
                        "red": color_data.get("red", 1.0),
                        "green": color_data.get("green", 0.0),
                        "blue": color_data.get("blue", 0.0)
                    }
                client_id = str(uuid.uuid4())
                
                if GAME.add_player(client_id, player_name, color=color) is None:
                    await websocket.close(code=1008, reason="Server is full")
                    print(f"Отклонено подключение для '{player_name}': сервер полон.")
                    return

                client_type = "player"
                PLAYER_CLIENTS[client_id] = websocket
                await websocket.send(json.dumps({"type": "assign_id", "payload": client_id}))
                print(f"Игрок '{player_name}' ({client_id}) подключился.")
            else:
                client_id = websocket
                client_type = "spectator"
                SPECTATOR_CLIENTS.add(websocket)
                print(f"Наблюдатель {websocket.remote_address} подключился.")
        else:
            return

        if client_type == "player":
            async for message in websocket:
                action = json.loads(message)
                GAME.handle_input(client_id, action)
        else:
            await websocket.wait_closed()

    except (websockets.exceptions.ConnectionClosed, json.JSONDecodeError):
        print(f"Соединение с {client_type if client_type else 'клиентом'} потеряно.")
    finally:
        if client_type == "player" and client_id in PLAYER_CLIENTS:
            del PLAYER_CLIENTS[client_id]
            GAME.remove_player(client_id)
        elif client_type == "spectator" and client_id in SPECTATOR_CLIENTS:
            SPECTATOR_CLIENTS.remove(client_id)
            print(f"Наблюдатель отключился.")

async def main():
    print("Запуск игрового цикла...")
    asyncio.create_task(game_loop())
    # Слушаем 0.0.0.0 для доступа из локальной сети
    async with websockets.serve(handler, "0.0.0.0", 8765):
        print("WebSocket сервер запущен на ws://0.0.0.0:8765")
        await asyncio.Future()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nСервер остановлен.")