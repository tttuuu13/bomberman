import pygame
import asyncio
import websockets
import json
import random
import math

# --- Константы ---
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600
TILE_SIZE = 40
SERVER_URI = "ws://localhost:8765" # ИСПРАВЛЕНО: URI вынесен в константу

# Цвета (расширенная палитра для стиля)
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
GRAY = (40, 40, 40)
LIGHT_GRAY = (100, 100, 100)
PLAYER_MAIN_COLOR = (50, 150, 255)
PLAYER_HEAD_COLOR = (150, 200, 255)
OTHER_PLAYER_MAIN_COLOR = (255, 140, 0)
OTHER_PLAYER_HEAD_COLOR = (255, 200, 150)
WALL_COLOR = (139, 141, 145)
WALL_SHADOW_COLOR = (85, 87, 91)
BRICK_COLOR = (181, 86, 56)
BRICK_MORTAR_COLOR = (212, 129, 102)
BOMB_BODY_COLOR = (20, 20, 20)
BOMB_FUSE_COLOR = (255, 255, 0)
EXPLOSION_COLORS = [(255, 107, 0), (255, 165, 0), (255, 208, 0)]
READY_GREEN = (0, 200, 0)
NOT_READY_YELLOW = (200, 200, 0)

# Глобальные переменные
game_state = {}
my_player_id = None

# Для визуальных эффектов
screen_shake = 0
explosion_particles = []
processed_explosion_coords = set() # УЛУЧШЕНИЕ: Для корректной обработки эффектов

# --- Меню ввода имени (без изменений) ---
def name_entry_menu(screen):
    font_title = pygame.font.Font(None, 74)
    font_input = pygame.font.Font(None, 50)
    name = ""
    input_box = pygame.Rect(SCREEN_WIDTH/2 - 150, SCREEN_HEIGHT/2 - 25, 300, 50)
    clock = pygame.time.Clock()

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT: return None, None
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_RETURN:
                    return (name, "player") if name else (None, "spectator")
                elif event.key == pygame.K_BACKSPACE:
                    name = name[:-1]
                else:
                    name += event.unicode
        
        screen.fill(BLACK)
        title_surf = font_title.render("BOMBERMAN", True, WHITE)
        screen.blit(title_surf, (SCREEN_WIDTH/2 - title_surf.get_width()/2, 150))
        
        pygame.draw.rect(screen, WHITE, input_box, 2)
        input_surf = font_input.render(name, True, WHITE)
        screen.blit(input_surf, (input_box.x + 10, input_box.y + 10))

        if (pygame.time.get_ticks() // 500) % 2 == 1:
            cursor_pos = input_box.x + 10 + input_surf.get_width()
            pygame.draw.line(screen, WHITE, (cursor_pos, input_box.y + 10), (cursor_pos, input_box.y + 40), 2)

        prompt_font = pygame.font.Font(None, 32)
        prompt_surf = prompt_font.render("Введите имя или оставьте пустым для наблюдения", True, LIGHT_GRAY)
        screen.blit(prompt_surf, (SCREEN_WIDTH/2 - prompt_surf.get_width()/2, SCREEN_HEIGHT/2 + 50))

        pygame.display.flip()
        clock.tick(60)

# --- Функции процедурной отрисовки (без изменений) ---
def draw_background(surface):
    for y in range(0, SCREEN_HEIGHT, TILE_SIZE):
        for x in range(0, SCREEN_WIDTH, TILE_SIZE):
            color = GRAY if (x // TILE_SIZE + y // TILE_SIZE) % 2 == 0 else (50, 50, 50)
            pygame.draw.rect(surface, color, (x, y, TILE_SIZE, TILE_SIZE))

def draw_wall(surface, rect):
    pygame.draw.rect(surface, WALL_SHADOW_COLOR, rect)
    pygame.draw.rect(surface, WALL_COLOR, rect.inflate(-4, -4))
    pygame.draw.line(surface, WHITE, rect.topleft, (rect.left + 5, rect.top + 5), 1)

def draw_brick(surface, rect):
    pygame.draw.rect(surface, BRICK_COLOR, rect)
    pygame.draw.line(surface, BRICK_MORTAR_COLOR, (rect.left, rect.centery), (rect.right, rect.centery))
    pygame.draw.line(surface, BRICK_MORTAR_COLOR, (rect.centerx, rect.top), (rect.centerx, rect.top + rect.height / 2))
    pygame.draw.line(surface, BRICK_MORTAR_COLOR, (rect.centerx, rect.bottom), (rect.centerx, rect.bottom - rect.height / 2))

def draw_player(surface, rect, is_me):
    main_color = PLAYER_MAIN_COLOR if is_me else OTHER_PLAYER_MAIN_COLOR
    head_color = PLAYER_HEAD_COLOR if is_me else OTHER_PLAYER_HEAD_COLOR
    body_rect = pygame.Rect(rect.x + 5, rect.y + 15, rect.width - 10, rect.height - 20)
    pygame.draw.rect(surface, main_color, body_rect, border_radius=5)
    pygame.draw.circle(surface, head_color, (rect.centerx, rect.centery - 5), 12)

def draw_bomb(surface, rect):
    pulse = abs(math.sin(pygame.time.get_ticks() * 0.01)) * 4
    pygame.draw.circle(surface, BOMB_BODY_COLOR, rect.center, TILE_SIZE // 2 - 4 + int(pulse))
    if (pygame.time.get_ticks() // 200) % 2 == 1:
        fuse_rect = pygame.Rect(rect.centerx - 2, rect.top + 2, 4, 8)
        pygame.draw.rect(surface, BOMB_FUSE_COLOR, fuse_rect)

def create_explosion_particles(x, y):
    for _ in range(20):
        particle = {
            'pos': [x * TILE_SIZE + TILE_SIZE / 2, y * TILE_SIZE + TILE_SIZE / 2],
            'vel': [random.uniform(-3, 3), random.uniform(-3, 3)],
            'lifespan': random.randint(15, 30),
            'color': random.choice(EXPLOSION_COLORS),
            'radius': random.uniform(2, 6)
        }
        explosion_particles.append(particle)

def update_and_draw_particles(surface, offset):
    for p in explosion_particles[:]:
        p['pos'][0] += p['vel'][0]
        p['pos'][1] += p['vel'][1]
        p['lifespan'] -= 1
        p['radius'] -= 0.1
        
        if p['lifespan'] <= 0 or p['radius'] <= 0:
            explosion_particles.remove(p)
        else:
            pos = (p['pos'][0] + offset[0], p['pos'][1] + offset[1])
            pygame.draw.circle(surface, p['color'], pos, p['radius'])

# --- Основные функции отрисовки (без изменений, кроме вызова эффектов) ---
def draw_text_overlay(screen, text, size=50):
    font = pygame.font.Font(None, size)
    text_surface = font.render(text, True, WHITE)
    text_rect = text_surface.get_rect(center=(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2))
    overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, 200))
    screen.blit(overlay, (0, 0))
    screen.blit(text_surface, text_rect)

def draw_game_state(screen, state):
    global screen_shake
    
    render_offset = [0, 0]
    if screen_shake > 0:
        screen_shake -= 1
        render_offset[0] = random.randint(-4, 4)
        render_offset[1] = random.randint(-4, 4)

    draw_background(screen)
    current_game_state = state.get("state", "WAITING")
    name_font = pygame.font.Font(None, 20)

    for y, row in enumerate(state.get("map", [])):
        for x, tile in enumerate(row):
            rect = pygame.Rect(x * TILE_SIZE + render_offset[0], y * TILE_SIZE + render_offset[1], TILE_SIZE, TILE_SIZE)
            if tile == '#': draw_wall(screen, rect)
            elif tile == '.': draw_brick(screen, rect)

    for bomb in state.get("bombs", []):
        rect = pygame.Rect(bomb['x'] * TILE_SIZE + render_offset[0], bomb['y'] * TILE_SIZE + render_offset[1], TILE_SIZE, TILE_SIZE)
        draw_bomb(screen, rect)
    
    update_and_draw_particles(screen, render_offset)

    for player in state.get("players", []):
        if player['alive']:
            rect = pygame.Rect(player['x'] * TILE_SIZE + render_offset[0], player['y'] * TILE_SIZE + render_offset[1], TILE_SIZE, TILE_SIZE)
            draw_player(screen, rect, player['id'] == my_player_id)
            name_surf = name_font.render(player.get('name', ''), True, WHITE)
            name_rect = name_surf.get_rect(center=(rect.centerx, rect.y - 10))
            screen.blit(name_surf, name_rect)

    if current_game_state == "IN_PROGRESS":
        time_remaining = state.get("time_remaining")
        if time_remaining is not None:
            minutes, seconds = divmod(max(0, int(time_remaining)), 60)
            timer_text = f"{minutes:02d}:{seconds:02d}"
            font = pygame.font.Font(None, 50)
            text_surf = font.render(timer_text, True, WHITE)
            text_rect = text_surf.get_rect(center=(SCREEN_WIDTH/2, 30))
            pygame.draw.rect(screen, BLACK, text_rect.inflate(20, 10), border_radius=10)
            screen.blit(text_surf, text_rect)

    elif current_game_state == "WAITING":
        draw_waiting_room(screen, state)

    elif current_game_state == "GAME_OVER":
        winner_text = f"Победитель: {state.get('winner', '')}" if state.get('winner') != "НИЧЬЯ" else "НИЧЬЯ"
        draw_text_overlay(screen, winner_text)

    pygame.display.flip()

def draw_waiting_room(screen, state):
    overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, 220))
    screen.blit(overlay, (0, 0))

    title_font = pygame.font.Font(None, 70)
    player_font = pygame.font.Font(None, 40)
    prompt_font = pygame.font.Font(None, 32)

    title_surf = title_font.render("ЛОББИ ОЖИДАНИЯ", True, WHITE)
    screen.blit(title_surf, (SCREEN_WIDTH/2 - title_surf.get_width()/2, 100))

    players = state.get('players', [])
    for i, player in enumerate(players):
        status = "ГОТОВ" if player.get('ready') else "НЕ ГОТОВ"
        color = READY_GREEN if player.get('ready') else NOT_READY_YELLOW
        player_text = f"{player.get('name', '???')}"
        
        card_rect = pygame.Rect(SCREEN_WIDTH/2 - 200, 200 + i * 60, 400, 50)
        pygame.draw.rect(screen, LIGHT_GRAY, card_rect, border_radius=10)
        
        player_surf = player_font.render(player_text, True, WHITE)
        screen.blit(player_surf, (card_rect.x + 15, card_rect.centery - player_surf.get_height()/2))
        
        status_surf = player_font.render(status, True, color)
        screen.blit(status_surf, (card_rect.right - status_surf.get_width() - 15, card_rect.centery - status_surf.get_height()/2))

    my_player = next((p for p in players if p['id'] == my_player_id), None)
    if my_player:
        ready_text = "Нажмите [R], чтобы отменить готовность" if my_player.get('ready') else "Нажмите [R] для готовности"
        prompt_surf = prompt_font.render(ready_text, True, WHITE)
        screen.blit(prompt_surf, (SCREEN_WIDTH/2 - prompt_surf.get_width()/2, SCREEN_HEIGHT - 100))

# ИСПРАВЛЕНО: Полностью переработанная функция для надежной обработки эффектов
def handle_visual_effects(new_state):
    global screen_shake, processed_explosion_coords
    
    # Получаем текущие координаты взрывов из нового состояния
    current_explosion_coords = {(e['x'], e['y']) for e in new_state.get("explosions", [])}
    
    # Находим взрывы, которые появились только что (которых не было в нашем списке)
    newly_appeared_explosions = current_explosion_coords - processed_explosion_coords
    
    if newly_appeared_explosions:
        for ex, ey in newly_appeared_explosions:
            create_explosion_particles(ex, ey)
        
        # Запускаем тряску, только если она еще не активна
        if screen_shake <= 0:
            screen_shake = 15
            
    # Обновляем наш список обработанных взрывов
    processed_explosion_coords = current_explosion_coords

# --- Сетевые и игровые циклы ---
async def listen_to_server(websocket):
    global game_state, my_player_id
    async for message in websocket:
        data = json.loads(message)
        if data.get("type") == "game_state":
            game_state = data.get("payload", game_state)
            handle_visual_effects(game_state) # Вызываем обновленную функцию
        elif data.get("type") == "assign_id":
            my_player_id = data.get("payload")

async def main_game_loop(screen, name, role):
    pygame.display.set_caption(f"Bomberman - {name if name else 'Наблюдатель'}")
    
    try:
        # ИСПРАВЛЕНО: Используем константу
        async with websockets.connect(SERVER_URI) as websocket:
            join_message = {"type": "join", "role": role}
            if role == "player": join_message["name"] = name
            await websocket.send(json.dumps(join_message))
            print(f"Подключено к {SERVER_URI} как {role}")
            
            listen_task = asyncio.create_task(listen_to_server(websocket))

            running = True
            while running:
                for event in pygame.event.get():
                    if event.type == pygame.QUIT: running = False
                    
                    if role == "player" and event.type == pygame.KEYDOWN:
                        current_state = game_state.get('state')
                        if current_state == 'WAITING':
                            if event.key == pygame.K_r:
                                await websocket.send(json.dumps({"type": "ready"}))
                        elif current_state == 'IN_PROGRESS':
                            action = None
                            if event.key == pygame.K_LEFT: action = {"type": "move", "dx": -1, "dy": 0}
                            elif event.key == pygame.K_RIGHT: action = {"type": "move", "dx": 1, "dy": 0}
                            elif event.key == pygame.K_UP: action = {"type": "move", "dx": 0, "dy": -1}
                            elif event.key == pygame.K_DOWN: action = {"type": "move", "dx": 0, "dy": 1}
                            elif event.key == pygame.K_SPACE: action = {"type": "place_bomb"}
                            if action: await websocket.send(json.dumps(action))
                
                if game_state:
                    draw_game_state(screen, game_state)
                
                await asyncio.sleep(0.01)

            listen_task.cancel()
    except (ConnectionRefusedError, websockets.exceptions.ConnectionClosed) as e:
        print(f"Не удалось подключиться к серверу: {e}")

# --- Точка входа ---
if __name__ == "__main__":
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    
    name, role = name_entry_menu(screen)
    
    if role:
        asyncio.run(main_game_loop(screen, name, role))
    
    pygame.quit()