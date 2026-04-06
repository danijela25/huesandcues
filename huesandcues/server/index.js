const WebSocket = require("ws");
const crypto = require("crypto");
const wss = new WebSocket.Server({ port: 3000 });
const rooms = {};

function generateRoomCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return rooms[code] ? generateRoomCode() : code;
}

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(data));
}

function broadcastToRoom(roomCode, data) {
  const room = rooms[roomCode];
  if (!room) return;
  room.players.forEach((player) => send(player.ws, data));
}

function canStart(room) {
  return room.players.length >= 2 && room.players.every((p) => p.ready);
}

function getLobbyState(room) {
  return {
    type: "lobby_state",
    roomCode: room.code,
    hostId: room.hostId,
    canStart: canStart(room),
    players: room.players.map((p) => ({ id: p.id, name: p.name, ready: p.ready, score: p.score })),
  };
}

wss.on("connection", (ws) => {
  ws.playerId = crypto.randomUUID();
  ws.roomCode = null;

  ws.on("message", (message) => {
    let data;
    try { data = JSON.parse(message.toString()); } catch { return; }

    if (data.type === "create_room") {
      const code = generateRoomCode();
      rooms[code] = {
        code, hostId: ws.playerId, status: "lobby",
        players: [{ id: ws.playerId, name: data.playerName || "Igrac", ready: false, score: 0, ws }]
      };
      ws.roomCode = code;
      send(ws, { type: "room_created", roomCode: code, playerId: ws.playerId });
      broadcastToRoom(code, getLobbyState(rooms[code]));
    }

    if (data.type === "join_room") {
      const room = rooms[data.roomCode];
      if (!room) return send(ws, { type: "error", message: "Soba nije pronadjena" });
      if (room.status !== "lobby") return send(ws, { type: "error", message: "Igra je vec pocela" });
      if (room.players.length >= 6) return send(ws, { type: "error", message: "Soba je puna" });
      room.players.push({ id: ws.playerId, name: data.playerName || "Igrac", ready: false, score: 0, ws });
      ws.roomCode = room.code;
      broadcastToRoom(room.code, getLobbyState(room));
    }

    if (data.type === "player_ready") {
      const room = rooms[ws.roomCode];
      if (!room) return;
      const player = room.players.find((p) => p.id === ws.playerId);
      if (!player) return;
      player.ready = !!data.ready;
      broadcastToRoom(room.code, getLobbyState(room));
    }

    if (data.type === "start_game") {
      const room = rooms[ws.roomCode];
      if (!room) return;
      if (room.hostId !== ws.playerId) return;
      if (!canStart(room)) return send(ws, { type: "error", message: "Nisu svi spremni" });

      room.status = "playing";
      room.cueGiverIndex = 0;
      room.secretTile = { x: Math.floor(Math.random() * 30), y: Math.floor(Math.random() * 16) };

      broadcastToRoom(room.code, {
        type: "game_start",
        cueGiverId: room.players[0].id,
        players: room.players.map((p) => ({ id: p.id, name: p.name, score: p.score })),
      });

      send(room.players[0].ws, { type: "secret_tile", tileX: room.secretTile.x, tileY: room.secretTile.y });
    }

    if (data.type === "submit_hint") {
      const room = rooms[ws.roomCode];
      if (!room) return;
      const cueGiver = room.players[room.cueGiverIndex];
      if (!cueGiver || cueGiver.id !== ws.playerId) return;
      broadcastToRoom(room.code, { type: "new_hint", hint: data.hint || "" });
    }

    if (data.type === "select_tile") {
      const room = rooms[ws.roomCode];
      if (!room) return;
      broadcastToRoom(room.code, {
        type: "tile_selected",
        playerId: ws.playerId,
        tileX: data.tileX,
        tileY: data.tileY,
      });
    }
  });

  ws.on("close", () => {
    const room = rooms[ws.roomCode];
    if (!room) return;
    room.players = room.players.filter((p) => p.id !== ws.playerId);
    if (room.players.length === 0) return delete rooms[ws.roomCode];
    if (room.hostId === ws.playerId) room.hostId = room.players[0].id;
    broadcastToRoom(room.code, getLobbyState(room));
  });
});

console.log("Server radi na ws://127.0.0.1:3000");